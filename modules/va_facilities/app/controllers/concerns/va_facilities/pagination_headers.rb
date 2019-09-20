# frozen_string_literal: true

# Implements GitHub-style Link header for pagination.
# URL derivation heavily cribbed from ActiveModelSerializers::Adapter::JsonApi
module VaFacilities
  module PaginationHeaders
    extend ActiveSupport::Concern

    LINK_FIRST_PAGE = 1

    def link_header(collection)
      @collection = collection
      links.map { |k, v| v.blank? ? nil : "<#{v}>; rel=\"#{k}\"" }.compact.join(', ')
    end

    def links
      {
        self: location_url,
        first: first_page_url,
        prev: prev_page_url,
        next: next_page_url,
        last: last_page_url
      }
    end

    private

    def location_url
      url_for_page(@collection.current_page)
    end

    def first_page_url
      url_for_page(1)
    end

    def last_page_url
      if @collection.total_pages.zero?
        url_for_page(LINK_FIRST_PAGE)
      else
        url_for_page(@collection.total_pages)
      end
    end

    def prev_page_url
      return nil if @collection.current_page == LINK_FIRST_PAGE
      url_for_page(@collection.current_page - LINK_FIRST_PAGE)
    end

    def next_page_url
      return nil if @collection.total_pages.zero? || @collection.current_page >= @collection.total_pages
      url_for_page(@collection.next_page)
    end

    def url_for_page(number)
      params = query_parameters.dup
      params[:page] = number
      params[:per_page] = per_page
      "#{url}?#{params.to_query}"
    end

    def url
      @link_url ||= request.original_url[/\A[^?]+/]
    end

    def query_parameters
      @link_query_parameters ||= request.query_parameters
    end

    def per_page
      @link_per_page ||= @collection.try(:per_page) || @collection.try(:limit_value) || @collection.size
    end
  end
end
