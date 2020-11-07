module Liquid
  module Rails
    class StylesheetPackTag < ::Liquid::Tag
      def initialize(tag_name, markup, tokens)
        @name = markup&.strip
      end

      def render(context)
        context.registers[:view].stylesheet_pack_tag(@name, 'data-turbolinks-track': 'reload')
      end
    end
  end
end

Liquid::Template.register_tag('stylesheet_pack_tag', Liquid::Rails::StylesheetPackTag)