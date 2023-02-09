# frozen_string_literal: true

module Mobile
  class PaginationHelper
    class InvalidParams < StandardError; end

    DEFAULT_PAGE_NUMBER = 1
    DEFAULT_PAGE_SIZE = 10

    attr_reader :list, :errors, :page_number, :page_size

    def initialize(list:, validated_params:, errors:)
      enforce_params_requirements(validated_params)
      @list = list
      @errors = errors
      @page_number = validated_params[:page_number] || DEFAULT_PAGE_NUMBER
      @page_size = validated_params[:page_size] || DEFAULT_PAGE_SIZE
    end

    def self.paginate(list:, validated_params:, errors: nil)
      new(list: list, validated_params: validated_params, errors: errors).paginate
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
        }
      }
      content = page_number > pages.size ? [] : pages[page_number - 1]

      [content, page_meta_data]
    end

    private

    def enforce_params_requirements(params)
      unless params.is_a?(Dry::Validation::Result)
        raise InvalidParams, 'Params must be a contract result. Use Mobile::V0::Contracts::PaginationBase or subclass.'
      end
    end
  end
end
