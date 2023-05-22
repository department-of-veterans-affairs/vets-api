# frozen_string_literal: true

module Mobile
  module V0
    class PreCacheAppointmentsJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      class MissingUserError < StandardError; end

      def perform(uuid)
        return unless Flipper.enabled?(:mobile_precache_appointments)

        user = IAMUser.find(uuid) || User.find(uuid)
        raise MissingUserError, uuid unless user

        Mobile::AppointmentsCacheInterface.new.fetch_appointments(user:, fetch_cache: false,
                                                                  cache_on_failures: false)
      end
    end
  end
end
