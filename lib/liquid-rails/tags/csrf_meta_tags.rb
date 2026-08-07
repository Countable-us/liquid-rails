module Liquid
  module Rails
    class CsrfMetaTags < ::Liquid::Tag
      def render(context)
        context.registers[:view].csrf_meta_tags.to_s
      end
    end
  end
end
