module Liquid
  module Filters
    module DevelopmentFilter
      def development_filter(input)
        "development: #{input}"
      end
    end
  end
end
