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

        _, failures = Mobile::AppointmentsCacheInterface.new.fetch_appointments(user:, fetch_cache: false,
                                                                                cache_on_failures: false)
        message = if failures.present?
                    'mobile appointments pre-cache fails with partial appointments present'
                  else
                    'mobile appointments pre-cache success'
                  end
        Rails.logger.info(message, user_uuid: uuid)
      end
    end
  end
end
