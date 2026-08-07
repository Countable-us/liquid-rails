module Liquid
  module Rails
    class CollectionDrop < ::Liquid::Drop
      class ArrayPagination
        include Enumerable

        def initialize(items, page: 1, per: nil)
          @items = items
          @page = page
          @per = per
        end

        def page(number)
          self.class.new(@items, page: number, per: @per)
        end

        def per(number)
          self.class.new(@items, page: @page, per: number)
        end

        def each(&block)
          paged_items.each(&block)
        end

        def [](index)
          paged_items[index]
        end

        def first
          paged_items.first
        end

        def last
          paged_items.last
        end

        def count(*args, &block)
          paged_items.count(*args, &block)
        end

        def size
          paged_items.size
        end
        alias_method :length, :size

        def empty?
          paged_items.empty?
        end

        def total_count
          @items.count
        end

        def total_pages
          return 1 unless @per

          (total_count.to_f / @per).ceil
        end

        private

        def paged_items
          return @items unless @per

          @items.slice((@page - 1) * @per, @per) || []
        end
      end

      class << self
        attr_accessor :_scopes
      end

      def self.inherited(base)
        base._scopes = []
      end

      def self.scope(*scope_names)
        @_scopes.concat scope_names

        scope_names.each do |scope_name|
          define_method(scope_name) do
            raise ::ArgumentError, "#{objects.class.name} doesn't define scope: #{scope_name}" unless objects.respond_to?(scope_name)

            self.class.new(objects.public_send(scope_name), options)
          end
        end
      end

      def self.unwrap(drop)
        raise ::ArgumentError, "expected CollectionDrop" unless drop.is_a?(CollectionDrop)

        drop.__send__(:objects)
      end

      def initialize(objects, options = {})
        @options = options.to_h.dup.freeze
        @objects = self.options[:scope].nil? ? objects : objects.public_send(self.options[:scope])
        @drop_class_name = self.options[:with]
      end

      def current_user
        options[:current_user]
      end

      def each
        return enum_for(__method__) unless block_given?

        objects.each { |item| yield drop_item(item, options) }
      end

      def load_slice(from, to)
        source = if objects.respond_to?(:offset) && objects.respond_to?(:limit)
          relation = objects.offset(from)
          to ? relation.limit(to - from) : relation
        else
          objects.slice(from...(to || objects.length)) || []
        end

        source.map { |item| drop_item(item, options) }
      end

      def [](method)
        if method.is_a?(Integer)
          drop_item(objects[method], options)
        elsif method.is_a?(String) && self.class._scopes.to_a.include?(method.to_sym)
          public_send(method)
        end
      end

      def first
        drop_item(objects.first, options)
      end

      def last
        drop_item(objects.last, options)
      end

      def count(*args, &block)
        objects.count(*args, &block)
      end

      def size
        objects.size
      end

      def length
        objects.length
      end

      def empty?
        objects.empty?
      end

      def page(number)
        collection = if objects.respond_to?(:page)
          objects.page(number)
        else
          ArrayPagination.new(objects).page(number)
        end

        self.class.new(collection, options)
      end

      def per(number)
        collection = if objects.respond_to?(:per)
          objects.per(number)
        else
          ArrayPagination.new(objects).per(number)
        end

        self.class.new(collection, options)
      end

      def total_count
        objects.total_count
      end

      def total_pages
        objects.total_pages
      end

      ## Need to override this. I don't understand too, otherwise it will return an array of drop objects.
      ## Need to return self so that we can do chaining.
      def to_liquid
        self
      end

      def inspect
        "#<#{self.class.name} of #{drop_class} for #{objects.inspect}>"
      end

      protected

      attr_reader :objects, :options

      def drop_class
        @drop_class ||= @drop_class_name.is_a?(String) ? @drop_class_name.safe_constantize : @drop_class_name
      end

      def drop_item(item, options = {})
        return if item.nil?

        liquid_drop_class = drop_class || Liquid::Rails::Drop.drop_class_for(item)
        liquid_drop_class.new(item, options)
      end
    end
  end
end
