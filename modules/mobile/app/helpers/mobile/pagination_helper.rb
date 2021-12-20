# frozen_string_literal: true

module Mobile
  class PaginationHelper
    DEFAULT_PAGE_NUMBER = 1
    DEFAULT_PAGE_SIZE = 10

    attr_reader :list, :validated_params, :url, :errors, :page_number, :page_size

    def initialize(list:, validated_params:, url:, errors:)
      @list = list
      @validated_params = validated_params
      @url = url
      @errors = errors
      @page_number = validated_params[:page_number] || DEFAULT_PAGE_NUMBER
      @page_size = validated_params[:page_size] || DEFAULT_PAGE_SIZE
    end

    def self.paginate(list:, validated_params:, url:, errors: nil)
      new(list: list, validated_params: validated_params, url: url, errors: errors).paginate
    end

    def paginate
      pages = list.each_slice(page_size).to_a

      page_meta_data = {
        errors: errors,
        meta: {
          pagination: {
            current_page: page_number,
            per_page: page_size,
            total_pages: pages.size,
            total_entries: list.size
          }
        },
        links: links(pages.size)
      }
      return [[], page_meta_data] if page_number > pages.size

      [pages[page_number - 1], page_meta_data]
    end

    private

    def links(number_of_pages)
      prev_link = link_url([page_number - 1, number_of_pages].min) if page_number > 1
      next_link = link_url([page_number + 1, number_of_pages].min) if page_number < number_of_pages

      {
        self: link_url(page_number),
        first: link_url('1'),
        prev: prev_link,
        next: next_link,
        last: link_url(number_of_pages)
      }
    end

    def link_url(display_page_number)
      "#{url_without_page_number}&page[number]=#{display_page_number}"
    end

    def url_without_page_number
      @url_without_page_number ||= begin
        query_strings = []
        %w[start_date end_date use_cache show_completed].each do |key|
          next unless validated_params.key?(key)

          camelized = key.camelize(:lower)
          query_strings << "#{camelized}=#{validated_params[key]}"
        end

        query_strings << "page[size]=#{page_size}"

        "#{url}?#{query_strings.join('&')}"
      end
    end
  end
end
