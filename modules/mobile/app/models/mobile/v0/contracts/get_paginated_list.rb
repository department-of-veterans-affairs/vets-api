# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class GetPaginatedList < Base
        params do
          optional(:start_date).maybe(:date_time, :filled?)
          optional(:end_date).maybe(:date_time, :filled?)
          optional(:page_number).maybe(:integer, :filled?)
          optional(:page_size).maybe(:integer, :filled?)
          optional(:use_cache).maybe(:bool, :filled?)
          optional(:reverse_sort).maybe(:bool, :filled?)
          optional(:show_completed).maybe(:bool, :filled?)
          optional(:included).maybe(:array, :filled?)
        end
      end
    end
  end
end
