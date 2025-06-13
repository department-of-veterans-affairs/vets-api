# frozen_string_literal: true

module Mobile
  class PaginationHelper
    class InvalidParams < StandardError; end

    DEFAULT_PAGE_NUMBER = 1
    DEFAULT_PAGE_SIZE = 10

    def self.paginate(list:, validated_params:, errors: nil)
      enforce_params_requirements(validated_params)
      page_number = validated_params[:page_number] || DEFAULT_PAGE_NUMBER
      page_size = validated_params[:page_size] || DEFAULT_PAGE_SIZE
      pages = list.each_slice(page_size).to_a

      page_meta_data = {
        errors:,
        meta: {
          pagination: {
            current_page: page_number,
            per_page: page_size,
            total_pages: pages.size,
            total_entries: list.size
          }
        }
      }
      content = page_number > pages.size ? [] : pages[page_number - 1]

      [content, page_meta_data]
    end

    class << self
      private

      def enforce_params_requirements(params)
        unless params.is_a?(Dry::Validation::Result)
          raise InvalidParams,
                'Params must be a contract result. Use Mobile::V0::Contracts::PaginationBase or subclass.'
        end
      end
    end
  end
end
