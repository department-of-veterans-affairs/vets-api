# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class GetAppointments < Base
        params do
          optional(:start_date).maybe(:date_time, :filled?)
          optional(:end_date).maybe(:date_time, :filled?)
          optional(:use_cache).maybe(:bool, :filled?)
        end
      end
    end
  end
end
