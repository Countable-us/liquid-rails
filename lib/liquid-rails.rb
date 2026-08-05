require 'liquid-rails/version'
require 'liquid'
require 'active_support/concern'

require 'liquid-rails/configuration'

require 'liquid-rails/filters/asset_tag_filter'
require 'liquid-rails/filters/asset_url_filter'
require 'liquid-rails/filters/date_filter'
require 'liquid-rails/filters/google_static_map_url_filter'
require 'liquid-rails/filters/misc_filter'
require 'liquid-rails/filters/number_filter'
require 'liquid-rails/filters/paginate_filter'
require 'liquid-rails/filters/sanitize_filter'
require 'liquid-rails/filters/text_filter'
require 'liquid-rails/filters/translate_filter'
require 'liquid-rails/filters/url_filter'

require 'liquid-rails/tags/content_for_tag'
require 'liquid-rails/tags/csrf_meta_tags'
require 'liquid-rails/tags/google_analytics_tag'
require 'liquid-rails/tags/javascript_pack_tag'
require 'liquid-rails/tags/javascript_tag'
require 'liquid-rails/tags/paginate_tag'
require 'liquid-rails/tags/stylesheet_pack_tag'

require 'liquid-rails/drops/droppable'
require 'liquid-rails/drops/collection_drop'
require 'liquid-rails/drops/drop'
require 'liquid-rails/file_system'
require 'liquid-rails/template_handler'
require 'liquid-rails/environment'

module Liquid
  module Rails
    class << self
      attr_reader :environment_generation

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
        reset_template_cache! if respond_to?(:reset_template_cache!, true)
      end

      def environment
        return @environment if @environment

        self.environment = build_environment(error_mode: :strict)
      end

      def environment=(environment)
        raise ArgumentError, "expected Liquid::Environment" unless environment.is_a?(::Liquid::Environment)

        @environment = environment
        @environment_generation = environment_generation.to_i + 1
      end
    end

    def self.setup_drop(base)
      base.class_eval do
        include Liquid::Rails::Droppable
      end
    end
  end
end

require 'liquid-rails/railtie' if defined?(Rails)
