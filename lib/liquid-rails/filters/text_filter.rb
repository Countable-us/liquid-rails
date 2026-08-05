module Liquid
  module Rails
    module TextFilter
      delegate \
        :highlight,
        :excerpt,
        :pluralize,
        :word_wrap,
        :simple_format,
        to: :__h__

      private

      def __h__
        @context.registers[:view]
      end
    end
  end
end
