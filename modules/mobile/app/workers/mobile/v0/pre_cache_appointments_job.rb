# frozen_string_literal: true

module Mobile
  module V0
    class PreCacheAppointmentsJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      def perform(uuid)
        user = IAMUser.find(uuid)
        start_date = (DateTime.now.utc.beginning_of_day - 3.months)
        end_date = (DateTime.now.utc.beginning_of_day + 6.months)

        appointments, errors = appointments_proxy(user).get_appointments(
          start_date: start_date,
          end_date: end_date,
          use_cache: false
        )

        if !errors.size.positive?
          options = { meta: { errors: nil } }
          json = Mobile::V0::AppointmentSerializer.new(appointments, options).serialized_json
          Mobile::V0::Appointment.set_cached_appointments(user, json)
          Rails.logger.info('mobile appointments pre-cache set succeeded', user_uuid: uuid)
        else
          Rails.logger.warn('mobile appointments pre-cache set failed', user_uuid: uuid, errors: errors)
        end
      end

      private

      def appointments_proxy(user)
        Mobile::V0::Appointments::Proxy.new(user)
      end
    end
  end
end
