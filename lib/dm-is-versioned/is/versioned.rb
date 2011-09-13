module DataMapper
  module Is
    ##
    # = Is Versioned
    # The Versioned module will configure a model to be versioned.
    #
    # The is-versioned plugin functions differently from other versioning
    # solutions (such as acts_as_versioned), but can be configured to
    # function like it if you so desire.
    #
    # The biggest difference is that there is not an incrementing 'version'
    # field, but rather, any field of your choosing which will be unique
    # on update.
    #
    # == Setup
    # For simplicity, I will assume that you have loaded dm-timestamps to
    # automatically update your :updated_at field. See versioned_spec for
    # and example of updating the versioned field yourself.
    #
    #   class Story
    #     include DataMapper::Resource
    #     property :id, Serial
    #     property :title, String
    #     property :updated_at, DateTime
    #
    #     is_versioned :on => [:updated_at]
    #   end
    #
    # == Auto Upgrading and Auto Migrating
    #
    #   Story.auto_migrate! # => will run auto_migrate! on Story::Version, too
    #   Story.auto_upgrade! # => will run auto_upgrade! on Story::Version, too
    #
    # == Usage
    #
    #   story = Story.get(1)
    #   story.title = "New Title"
    #   story.save # => Saves this story and creates a new version with the
    #              #    original values.
    #   story.versions.size # => 1
    #
    #   story.title = "A Different New Title"
    #   story.save
    #   story.versions.size # => 2
    #
    # TODO: enable replacing a current version with an old version.
    module Versioned
      def is_versioned(options = {})
        @on = on = self.properties.values_at(*options[:on])

        extend(Migration) if respond_to?(:auto_migrate!)

        before :save do                    
          if on.one? {|o| dirty_attributes.keys.include? o }
            self.pending_version_attributes = original_attributes
          end
        end

        after :update do
          if clean? && !pending_version_attributes.empty?
            model::Version.create(attributes.merge(pending_version_attributes))
            self.pending_version_attributes = nil
          end
        end

        extend ClassMethods
        include InstanceMethods
      end

      module ClassMethods
        def const_missing(name)
          if name == :Version
            model = DataMapper::Model.new(name, self)

            properties.each do |property|
              type = case property
                when DataMapper::Property::Discriminator then Class
                when DataMapper::Property::Serial        then Integer
              else
                property.class
              end

              options = property.options.merge(:key => property.name == @on)

              options[:key] = true if options.delete(:serial)

              model.property(property.name, type, options)
            end

            model
          else
            super
          end
        end
      end # ClassMethods

      module InstanceMethods
        ##
        # Returns a hash of original values to be stored in the
        # versions table when a new version is created. It is
        # cleared after a version model is created.
        #
        # --
        # @return <Hash>
        def pending_version_attributes
          @pending_version_attributes ||= {}
        end
        
        ##
        # Allows the set the original values Hash. If the Hash is present,
        # a Version will be created after save.
        # 
        # --
        # @return <Hash>
        def pending_version_attributes=(attributes)
          @pending_version_attributes = attributes
        end

        ##
        # Returns a collection of other versions of this resource.
        # The versions are related on the models keys, and ordered
        # by the version field.
        #
        # --
        # @return <Collection>
        def versions
          version_model = model.const_get(:Version)
          query = Hash[ model.key.zip(key).map { |p, v| [ p.name, v ] } ]
          query.merge(:order => version_model.key.map { |k| k.name.desc })
          version_model.all(query)
        end
      end # InstanceMethods

      module Migration

        def auto_migrate!(repository_name = self.repository_name)
          super
          self::Version.auto_migrate!
        end

        def auto_upgrade!(repository_name = self.repository_name)
          super
          self::Version.auto_upgrade!
        end

      end # Migration

    end # Versioned
  end # Is
end # DataMapper
