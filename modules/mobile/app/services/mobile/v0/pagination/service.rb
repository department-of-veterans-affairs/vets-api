# frozen_string_literal: true

module Mobile
  module V0
    module Pagination
      class Service
        def paginate(list, params, request)
          page_size = params[:page_size]
          page_number = params[:page_number]
          list = list.filter do |entry|
            updated_at = entry[:updated_at]
            updated_at >= params[:start_date] && updated_at <= params[:end_date]
          end
          total_entries = list.length
          list = list.slice(((page_number - 1) * page_size), page_size)
          total_pages = (total_entries / page_size.to_f).ceil
          [list,
           {
               currentPage: page_number,
               perPage: page_size,
               totalPages: total_pages,
               totalEntries: total_entries
           },
           links(total_pages, params, request)]
        end

        private

        def links(number_of_pages, validated_params, request)
          page_number = validated_params[:page_number]
          page_size = validated_params[:page_size]

          query_string = "?startDate=#{validated_params[:start_date]}&endDate=#{validated_params[:end_date]}"\
          "&useCache=#{validated_params[:use_cache]}"
          url = request.base_url + request.path + query_string

          if page_number > 1
            prev_link = "#{url}&page[number]=#{[page_number - 1,
                                                number_of_pages].min}&page[size]=#{page_size}"
          end

          if page_number < number_of_pages
            next_link = "#{url}&page[number]=#{[page_number + 1,
                                                number_of_pages].min}&page[size]=#{page_size}"
          end

          {
              self: "#{url}&page[number]=#{page_number}&page[size]=#{page_size}",
              first: "#{url}&page[number]=1&page[size]=#{page_size}",
              prev: prev_link,
              next: next_link,
              last: "#{url}&page[number]=#{number_of_pages}&page[size]=#{page_size}"
          }
        end
      end
    end
  end
end

