# frozen_string_literal: true

module Mobile
  module V0
    class PreCacheAppointmentsJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      def perform(uuid)
        return unless Flipper.enabled?(:mobile_precache_appointments)

        Rails.logger.info('mobile appointments pre-cache attempt', user_uuid: uuid)

        user = IAMUser.find(uuid)
        Mobile::AppointmentsCacheInterface.new.fetch_appointments(user: user, fetch_cache: false)

        Rails.logger.warn('mobile appointments pre-cache success', user_uuid: uuid)
      end
    end
  end
end
