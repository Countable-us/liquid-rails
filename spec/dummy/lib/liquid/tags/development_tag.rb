module Liquid
  module Tags
    class DevelopmentTag < Liquid::Tag
      def render(_context)
        "development tag"
      end
    end
  end
end
