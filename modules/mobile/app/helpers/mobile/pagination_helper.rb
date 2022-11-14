# frozen_string_literal: true

module Mobile
  class PaginationHelper
    class InvalidParams < StandardError; end

    DEFAULT_PAGE_NUMBER = 1
    DEFAULT_PAGE_SIZE = 10

    attr_reader :list, :optional_params, :url, :errors, :page_number, :page_size

    def initialize(list:, validated_params:, url:, errors:)
      enforce_params_requirements(validated_params)
      @list = list
      @url = url
      @errors = errors
      @page_number = validated_params[:page_number] || DEFAULT_PAGE_NUMBER
      @page_size = validated_params[:page_size] || DEFAULT_PAGE_SIZE
      @optional_params = validated_params.to_h.except(:page_number, :page_size)
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
      content = page_number > pages.size ? [] : pages[page_number - 1]

      [content, page_meta_data]
    end

    private

    def links(number_of_pages)
      prev_link = page_number > 1 ? link_url([page_number - 1, number_of_pages].min) : nil
      next_link = page_number < number_of_pages ? link_url([page_number + 1, number_of_pages].min) : nil
      last_link_page_number = number_of_pages.positive? ? number_of_pages : 1

      {
        self: link_url(page_number),
        first: link_url(1),
        prev: prev_link,
        next: next_link,
        last: link_url(last_link_page_number)
      }
    end

    def link_url(display_page_number)
      params = ["page[size]=#{page_size}", "page[number]=#{display_page_number}", *optional_query_strings].join('&')
      "#{url}?#{params}"
    end

    # rubocop:disable Metrics/MethodLength
    def optional_query_strings
      @optional_query_strings ||= begin
        query_strings = []

        optional_params.each_pair do |key, value|
          next if value.to_s.blank?

          camelized = key.to_s.camelize(:lower)
          case value
          when Array
            value.each do |v|
              query_strings << "#{camelized}[]=#{v}"
            end
          when Hash

            # this is an incomplete implementation that serves our current needs
            # this will need additional work if we ever need to use more complex hashes
            first_key = value.keys.first
            second_key = value.values.first&.keys&.first
            final_value = value.values.first&.values&.first

            if [first_key, second_key, final_value].any?(&:blank?)
              raise InvalidParams, "Invalid hash -- #{key}: #{value}"
            end

            query_strings << "#{key}[[#{first_key}][#{second_key}]]=#{final_value}"
          else
            query_strings << "#{camelized}=#{value}"
          end
        end

        query_strings
      end
    end
    # rubocop:enable Metrics/MethodLength

    def enforce_params_requirements(params)
      unless params.is_a?(Dry::Validation::Result)
        raise InvalidParams, 'Params must be a contract result. Use Mobile::V0::Contracts::PaginationBase or subclass.'
      end
    end
  end
end
