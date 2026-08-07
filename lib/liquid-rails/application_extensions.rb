require "active_support/core_ext/string/inflections"
require "active_support/dependencies"
require "pathname"

module Liquid
  module Rails
    class ApplicationExtensions
      def initialize(root:, configuration:)
        @root = Pathname.new(root)
        @configuration = configuration
      end

      def register(environment)
        register_filters(environment)
        register_tags(environment)

        environment
      end

      private

      attr_reader :configuration, :root

      def register_filters(environment)
        extensions_in(configuration.filters_location).each do |file|
          environment.register_filter(load_extension(file, :Filters))
        end
      end

      def register_tags(environment)
        extensions_in(configuration.tags_location).each do |file|
          environment.register_tag(file.basename(".rb").to_s, load_extension(file, :Tags))
        end
      end

      def extensions_in(location)
        return [] unless location

        directory = Pathname.new(location)
        directory = root.join(directory) unless directory.absolute?
        return [] unless directory.directory?

        directory.children.select { |file| file.file? && file.extname == ".rb" }.sort
      end

      def extension_constant(file, namespace)
        ::Liquid.const_get(namespace).const_get(file.basename(".rb").to_s.camelize, false)
      end

      def load_extension(file, namespace)
        require_dependency(file.to_s)
        load(file.to_s) unless extension_defined?(file, namespace)

        extension_constant(file, namespace)
      end

      def extension_defined?(file, namespace)
        ::Liquid.const_defined?(namespace, false) &&
          ::Liquid.const_get(namespace).const_defined?(file.basename(".rb").to_s.camelize, false)
      end
    end
  end
end
