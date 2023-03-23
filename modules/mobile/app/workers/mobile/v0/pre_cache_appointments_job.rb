# frozen_string_literal: true

module Mobile
  module V0
    class PreCacheAppointmentsJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      class MissingUserError < StandardError; end

      def perform(uuid)
        return unless Flipper.enabled?(:mobile_precache_appointments)

        Rails.logger.info('mobile appointments pre-cache attempt', user_uuid: uuid)

        user = IAMUser.find(uuid) || User.find(uuid)
        raise MissingUserError, uuid unless user

        Mobile::AppointmentsCacheInterface.new.fetch_appointments(user:, fetch_cache: false)

        Rails.logger.info('mobile appointments pre-cache success', user_uuid: uuid)
      end
    end
  end
end
