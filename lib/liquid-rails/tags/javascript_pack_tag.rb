module Liquid
  module Rails
    class JavascriptPackTag < ::Liquid::Tag
      def initialize(tag_name, markup, tokens)
        @name = markup&.strip
      end

      def render(context)
        context.registers[:view].javascript_pack_tag(@name, 'data-turbo-track': 'reload')
      end
    end
  end
end

Liquid::Rails.register_tag('javascript_pack_tag', Liquid::Rails::JavascriptPackTag)
