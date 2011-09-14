require 'spec_helper'

class Story
  include DataMapper::Resource

  property :id,         Serial
  property :title,      String
  property :updated_at, DateTime
  property :type,       Discriminator

  before :save do
    # For the sake of testing, make sure the updated_at is always unique
    # use set_attribute to make sure that versioning works if accessors
    # are not used
    if dirty?
      time = self.updated_at ? self.updated_at + 1 : Time.now
      self.attribute_set(:updated_at, time)
    end
  end

  is_versioned :on => :updated_at
end

describe 'DataMapper::Is::Versioned' do

  supported_by :sqlite, :mysql, :postgres do

    describe 'inner class' do
      it 'should be present' do
        Story::Version.should be_a_kind_of(DataMapper::Model)
      end

      it 'should have a default storage name' do
        Story::Version.storage_name.should == 'story_versions'
      end

      Story.properties.each do |property|
        it "should have its parent's property #{property.name}" do
          Story::Version.properties.any? do |version_property|
            version_property.name      == property.name &&
            version_property.primitive == property.primitive
          end
        end
      end
    end

    describe '#create' do
      before :all do
        Story.create(:title => 'A Very Interesting Article')
      end

      it 'should not create a versioned copy' do
        Story::Version.all.size.should == 0
      end
    end

    describe '#save' do
      describe '(with new resource)' do
        before :all do
          @story = Story.new(:title => 'A Story')
          @story.save.should be(true)
        end

        it 'should not create a versioned copy' do
          Story::Version.all.size.should == 0
        end
      end

      describe '(with a clean existing resource)' do
        before :all do
          @story = Story.create(:title => 'A Story')
          @story.save.should be(true)
        end

        it 'should not create a versioned copy' do
          Story::Version.all.size.should == 0
        end
      end

      # FIXME: temporarily disable specs that fail with the current DO gem
      unless defined?(DataObjects::VERSION) &&
        DataObjects::VERSION <= '0.10.3'    &&
        RUBY_PLATFORM        =~ /java/      &&
        JRUBY_VERSION        >= '1.6'       &&
        RUBY_VERSION         >= '1.9.2'

        describe '(with a dirty existing resource)' do
          before :all do
            @story = Story.create(:title => 'A Story')
            @story.title = 'An Inner Update'
            @story.title = 'An Updated Story'
            @story.save.should be(true)
          end

          it 'should create a versioned copy' do
            Story::Version.all.size.should == 1
          end

          it 'should not have the same value for the versioned field' do
            @story.updated_at.should_not == Story::Version.first.updated_at
          end

          it 'should save the original value, not the inner update' do
            # changes to the story between saves shouldn't be updated.
            @story.versions.last.title.should == 'A Story'
          end
        end
      end
    end

    describe '#versions' do
      before :all do
        @story = Story.create(:title => 'A Story')
        @story.should be_saved
      end

      it 'should return an empty array when there are no versions' do
        @story.versions.should == []
      end

      it 'should return a collection when there are versions' do
        @story.versions.should == Story::Version.all(:id => @story.id)
      end

      it "should not return another object's versions" do
        @story2 = Story.create(:title => 'A Different Story')
        @story2.title = 'A Different Title'
        @story2.save.should be(true)
        @story.versions.should == Story::Version.all(:id => @story.id)
      end
    end

  end

end
