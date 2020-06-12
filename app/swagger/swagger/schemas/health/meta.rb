# frozen_string_literal: true

module Swagger
  module Schemas
    module Health
      class Meta
        include Swagger::Blocks

        swagger_schema :MetaPagination do
          key :type, :object
          key :required, [:pagination]

          property :pagination, '$ref': :Pagination
        end

        swagger_schema :MetaFailedStationList do
          key :type, :object
          key :required, %i[updated_at failed_station_list]

          property :updated_at, type: :string
          property :failed_station_list, type: :string
        end

        swagger_schema :MetaFailedStationListSortPagination do
          key :type, :object
          key :required, %i[updated_at failed_station_list sort pagination]

          property :updated_at, type: :string
          property :failed_station_list, type: %i[null string]

          property :pagination, '$ref': :Filter
          property :pagination, '$ref': :Sort
          property :pagination, '$ref': :Pagination
        end

        swagger_schema :MetaFilterSortPagination do
          key :type, :object
          key :required, %i[filter sort pagination]

          property :pagination, '$ref': :Filter
          property :pagination, '$ref': :Sort
          property :pagination, '$ref': :Pagination
        end

        swagger_schema :MetaSortPagination do
          key :type, :object
          key :required, %i[sort pagination]

          property :pagination, '$ref': :Sort
          property :pagination, '$ref': :Pagination
        end

        swagger_schema :MetaSort do
          key :type, :object
          key :required, %i[sort]

          property :pagination, '$ref': :Sort
        end

        swagger_schema :Filter do
          key :type, :object
        end

        swagger_schema :Sort do
          key :type, :object
        end

        swagger_schema :Pagination do
          key :type, :object
          key :required, %i[current_page per_page total_pages total_entries]

          property :current_page, type: :integer
          property :per_page, type: :integer
          property :total_pages, type: :integer
          property :total_entries, type: :integer
        end
      end
    end
  end
end
