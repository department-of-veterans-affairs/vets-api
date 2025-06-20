# frozen_string_literal: true

require 'lighthouse/facilities/client'

module Mobile
  module V2
    module Appointments
      class Proxy
        VAOS_STATUSES = %w[proposed cancelled booked fulfilled arrived].freeze

        def initialize(user)
          @user = user
        end

        def get_appointments(start_date:, end_date:, include_pending:, include_claims: false, pagination_params: {})
          statuses = include_pending ? VAOS_STATUSES : VAOS_STATUSES.excluding('proposed')

          include_params = {
            clinics: true,
            facilities: true,
            travel_pay_claims: include_claims
          }

          # VAOS V2 appointments service accepts pagination params but either it formats them incorrectly
          # or the upstream service does not use them.
          response = vaos_v2_appointments_service.get_appointments(start_date, end_date, statuses.join(','),
                                                                   pagination_params, include_params, 'mobile')

          appointments = response[:data]

          unless Flipper.enabled?(:appointments_consolidation, @user)
            filterer = VAOS::V2::AppointmentsPresentationFilter.new
            appointments.keep_if { |appt| filterer.user_facing?(appt) }
          end

          appointments = vaos_v2_to_v0_appointment_adapter.parse(appointments)

          [appointments.sort_by(&:start_date_utc), response[:meta][:failures]]
        end

        private

        def vaos_v2_appointments_service
          VAOS::V2::AppointmentsService.new(@user)
        end

        def vaos_v2_to_v0_appointment_adapter
          Mobile::V0::Adapters::VAOSV2Appointments.new
        end
      end
    end
  end
end
