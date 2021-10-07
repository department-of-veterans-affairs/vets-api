# frozen_string_literal: true

module Mobile
  module PaginationLinksHelper
    module_function

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
