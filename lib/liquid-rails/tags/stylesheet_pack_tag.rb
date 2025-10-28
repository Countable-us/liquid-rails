module Liquid
  module Rails
    class StylesheetPackTag < ::Liquid::Tag
      def initialize(tag_name, markup, tokens)
        @name = markup&.strip
      end

      def render(context)
        context.registers[:view].stylesheet_pack_tag(@name, 'data-turbo-track': 'reload')
      end
    end
  end
end

Liquid::Rails.register_tag('stylesheet_pack_tag', Liquid::Rails::StylesheetPackTag)
