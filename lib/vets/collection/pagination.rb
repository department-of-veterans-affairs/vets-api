require 'common/exceptions/invalid_pagination_params'

module Vets
  module Collection
    class Pagination

      def initialize(page:, per_page:, total_entries:, data:, use_will_paginate: false)
        @page = page
        @per_page = per_page
        @total_entries = total_entries

        if use_will_paginate && defined?(::WillPaginate::Collection)
          @data = will_paginate_collection(data)
        else
          @data = data[((page - 1) * per_page)...(page * per_page)]
        end
      end

      private

      def total_pages
        (total_entries / per_page.to_f).ceil
      end

      def metadata
        {
          pagination: {
            current_page: page,
            per_page:,
            total_pages: total_pages,
            total_entries:
          }
        }
      end

      def will_paginate_collection(records)
        WillPaginate::Collection.create(page, per_page, total_entries) do |pager|
          raise Common::Exceptions::InvalidPaginationParams.new({ page:, per_page: }) if pager.out_of_bounds?

          pager.replace records[pager.offset, pager.per_page]
        end
      end
    end
  end
end
