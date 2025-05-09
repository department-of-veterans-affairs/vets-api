# frozen_string_literal: true

require 'common/exceptions/invalid_pagination_params'

module Vets
  module Collections
    class Pagination
      attr_reader :data

      def initialize(page:, per_page:, total_entries:, data:, use_will_paginate: false)
        @page = page
        @per_page = per_page
        @total_entries = total_entries || 0

        @data = if data.nil?
                  []
                elsif use_will_paginate && defined?(::WillPaginate::Collection)
                  will_paginate_collection(data)
                else
                  validate_out_of_bounds
                  data[((page - 1) * per_page)...(page * per_page)]
                end
      end

      def metadata
        {
          pagination: {
            current_page: @page,
            per_page: @per_page,
            total_pages:,
            total_entries: @total_entries
          }
        }
      end

      private

      def total_pages
        return 1 if @total_entries.zero?

        (@total_entries / @per_page.to_f).ceil
      end

      def will_paginate_collection(records)
        WillPaginate::Collection.create(@page, @per_page, @total_entries) do |pager|
          if pager.out_of_bounds?
            error_params = { page: @page, per_page: @per_page }
            raise Common::Exceptions::InvalidPaginationParams, error_params
          end

          pager.replace records[pager.offset, pager.per_page]
        end
      end

      def validate_out_of_bounds
        error_params = { page: @page, per_page: @per_page }
        raise Common::Exceptions::InvalidPaginationParams, error_params if @page > total_pages
      end
    end
  end
end
