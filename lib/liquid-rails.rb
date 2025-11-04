require 'liquid-rails/version'
require 'liquid'
require 'kaminari'
require 'active_support/concern'

module Liquid
  module Rails
    class << self
      def environment
        return unless defined?(::Liquid::Environment)
        @environment ||= ::Liquid::Environment.default
      end

      def register_filter(filter)
        if environment
          environment.register_filter(filter)
        else
          ::Liquid::Template.register_filter(filter)
        end
      end

      def register_tag(name, tag)
        if environment
          environment.register_tag(name, tag)
        else
          ::Liquid::Template.register_tag(name, tag)
        end
      end
    end

    autoload :TemplateHandler,  'liquid-rails/template_handler'
    autoload :FileSystem,       'liquid-rails/file_system'

    autoload :Drop,             'liquid-rails/drops/drop'
    autoload :CollectionDrop,   'liquid-rails/drops/collection_drop'

    def self.setup_drop(base)
      base.class_eval do
        include Liquid::Rails::Droppable
      end
    end
  end
end

require 'liquid-rails/railtie' if defined?(Rails)
Dir[File.dirname(__FILE__) + '/liquid-rails/{filters,tags,drops}/*.rb'].each { |f| require f }
