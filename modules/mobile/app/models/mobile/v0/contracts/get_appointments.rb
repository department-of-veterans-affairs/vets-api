# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class GetAppointments < Base
        params do
          required(:start_date).filled(:date_time)
          required(:end_date).filled(:date_time)
          required(:use_cache).filled(:bool)
        end
      end
    end
  end
end
