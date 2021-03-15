# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class CancelAppointment < Base
        params do
          required(:appointmentTime).filled(:date_time)
          required(:clinicId).filled(:string)
          required(:facilityId).filled(:string)
          required(:healthcareService).filled(:string)
        end
      end
    end
  end
end
