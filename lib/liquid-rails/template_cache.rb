module Liquid
  module Rails
    class TemplateCache
      MISSING = Object.new.freeze

      attr_reader :max_size

      def initialize(max_size:)
        @max_size = Integer(max_size)
        @entries = {}
        @mutex = Mutex.new
      end

      def fetch(key)
        cached = @mutex.synchronize do
          next MISSING unless @entries.key?(key)

          @entries[key] = @entries.delete(key)
        end
        return cached unless cached.equal?(MISSING)

        value = yield
        @mutex.synchronize do
          @entries.delete(key)
          @entries[key] = value
          @entries.shift while @entries.size > max_size
        end
        value
      end

      def size
        @mutex.synchronize { @entries.size }
      end
    end
  end
end
