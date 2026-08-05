module Liquid
  module Rails
    class Configuration
      RENDER_ERROR_POLICIES = %i[raise embed].freeze

      attr_reader :cache_namespace, :cache_size, :render_errors

      def initialize
        @cache_namespace = nil
        @cache_size = 1_000
        @render_errors = :raise
      end

      def cache_size=(value)
        value = Integer(value)
        raise ArgumentError, "cache_size must be positive" unless value.positive?

        @cache_size = value
      end

      def cache_namespace=(value)
        raise ArgumentError, "cache_namespace must respond to call" if value && !value.respond_to?(:call)

        @cache_namespace = value
      end

      def render_errors=(value)
        value = value.to_sym
        raise ArgumentError, "render_errors must be :raise or :embed" unless RENDER_ERROR_POLICIES.include?(value)

        @render_errors = value
      end
    end
  end
end
