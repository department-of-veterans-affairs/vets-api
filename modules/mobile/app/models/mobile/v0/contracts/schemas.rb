# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      module Schemas
        PaginationSchema = Dry::Schema.Params do
          optional(:page_number).maybe(:integer, :filled?)
          optional(:page_size).maybe(:integer, :filled?)
        end

        DateRangeSchema = Dry::Schema.Params do
          optional(:start_date).maybe(:date_time, :filled?)
          optional(:end_date).maybe(:date_time, :filled?)
        end
      end
    end
  end
end
