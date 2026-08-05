module Liquid
  module Rails
    DEFAULT_FILTERS = [
      AssetTagFilter,
      AssetUrlFilter,
      DateFilter,
      GoogleStaticMapUrlFilter,
      MiscFilter,
      NumberFilter,
      PaginateFilter,
      SanitizeFilter,
      TextFilter,
      TranslateFilter,
      UrlFilter
    ].freeze

    DEFAULT_TAGS = {
      "content_for" => ContentForTag,
      "yield" => YieldTag,
      "csrf_meta_tags" => CsrfMetaTags,
      "google_analytics_tag" => GoogleAnalyticsTag,
      "javascript_pack_tag" => JavascriptPackTag,
      "javascript_tag" => JavascriptTag,
      "paginate" => PaginateTag,
      "stylesheet_pack_tag" => StylesheetPackTag
    }.freeze

    class << self
      def build_environment(error_mode:)
        ::Liquid::Environment.build(error_mode:) do |environment|
          DEFAULT_FILTERS.each { |filter| environment.register_filter(filter) }
          DEFAULT_TAGS.each { |name, tag| environment.register_tag(name, tag) }
          yield environment if block_given?
        end
      end
    end
  end
end
