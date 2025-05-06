# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class TravelPaySmoc < Base
        params do
          required(:appointment_date_time).filled(:date_time)
          required(:facility_station_number).filled(:string)
          required(:appointment_type).filled(:string)
          required(:is_complete).filled(:bool)
          # This is optional but will fail if passed an empty string
          optional(:appointment_name).filled(:string)
        end
      end
    end
  end
end
