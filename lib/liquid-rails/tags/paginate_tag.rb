# Paginate a collection
#
# Usage:
#
# {% paginate listing.photos by 5 %}
#   {% for photo in paginate.collection %}
#     {{ photo.caption }}
#   {% endfor %}
#  {% endpaginate %}
#
module Liquid
  module Rails
    class PaginateTag < ::Liquid::Block
      Syntax = /(#{::Liquid::QuotedFragment})\s*(by\s*(\d+))?/

      def initialize(tag_name, markup, context)
        super

        if markup =~ Syntax
          @collection_name = $1
          @page_size = if $2
            $3.to_i
          else
            25
          end

          @attributes = { 'window_size' => 3 }
          markup.scan(Liquid::TagAttributes) do |key, value|
            @attributes[key] = value
          end
        else
          raise SyntaxError.new("Syntax Error in tag 'paginate' - Valid syntax: paginate [collection] by number")
        end
      end

      def render(context)
        context.stack do
          collection = context[@collection_name].presence || context.environments[0][@collection_name]
          raise ::Liquid::ArgumentError.new("Cannot paginate collection '#{@collection_name}'. Not found.") if collection.nil?

          active_page = current_page(context)

          if collection.is_a? Array
            paginated_collection = Kaminari.paginate_array(collection.to_a).page(active_page).per(@page_size)
          elsif collection.respond_to?(:page)
            paginated_collection = collection.page(active_page).per(@page_size)
          end

          page_count = paginated_collection.total_pages
          pagination = {}
          pagination['collection']      = paginated_collection
          pagination['current_offset']  = (active_page-1) * @page_size
          pagination['current_page']    = active_page
          pagination['page_size']       = @page_size
          pagination['pages']           = page_count
          pagination['items']           = paginated_collection.total_count
          pagination['previous']        = link(context, '&laquo; Previous'.html_safe, active_page-1 ) unless 1 >= active_page
          pagination['next']            = link(context, 'Next &raquo;'.html_safe, active_page+1 )     unless page_count < active_page+1
          pagination['parts']           = []

          hellip_break = false
          if page_count > 1
            1.upto(page_count) do |page|

              if active_page == page
                pagination['parts'] << no_link(page)
              elsif page == 1
                pagination['parts'] << link(context, page, page)
              elsif page == page_count - 1
                pagination['parts'] << link(context, page, page)
              elsif page <= active_page - window_size or page >= active_page + window_size
                next if hellip_break
                pagination['parts'] << no_link('&hellip;')
                hellip_break = true
                next
              else
                pagination['parts'] << link(context, page, page)
              end

              hellip_break = false
            end
          end
          context['paginate'] = pagination

          super
        end
      end

      private

        def current_page(context)
          _current_page = context.registers[:controller].params[:page]
          _current_page.nil? ? 1 : _current_page.to_i
        end

        def current_url(context)
          current_url = context.registers[:controller].request.fullpath.gsub(/page=[0-9]+&?/, '')
          current_url = current_url.slice(0..-2) if current_url.last == '?' || current_url.last == '&'
          current_url
        end

        def window_size
          @attributes['window_size']
        end

        def no_link(title)
          { 'title' => title, 'is_link' => false, 'hellip_break' => (title == '&hellip;') }
        end

        def link(context, title, page)
          url = current_url(context)
          _current_url = %(#{url}#{url.include?('?') ? '&' : '?'}page=#{page})
          { 'title' => title, 'url' => _current_url, 'is_link' => true }
        end
    end
  end
end
