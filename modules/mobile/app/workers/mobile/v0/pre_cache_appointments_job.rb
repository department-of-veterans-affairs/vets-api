# frozen_string_literal: true

module Mobile
  module V0
    class PreCacheAppointmentsJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      def perform(uuid)
        Rails.logger.info('mobile appointments pre-cache attempt', user_uuid: uuid)

        user = IAMUser.find(uuid)
        start_date = (DateTime.now.utc.beginning_of_year - 1.year)
        end_date = (DateTime.now.utc.beginning_of_day + 1.year)

        appointments = appointments_proxy(user).get_appointments(
          start_date: start_date,
          end_date: end_date
        )

        Mobile::V0::Appointment.set_cached(user, appointments)
        Rails.logger.warn('mobile appointments pre-cache success', user_uuid: uuid)
      end

      private

      def appointments_proxy(user)
        Mobile::V0::Appointments::Proxy.new(user)
      end
    end
  end
end
