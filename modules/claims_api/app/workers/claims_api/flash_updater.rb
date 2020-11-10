# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module ClaimsApi
  class FlashUpdater
    include Sidekiq::Worker
    include SentryLogging

    def perform(user, flashes)
      service = bgs_service(user).claimant

      flashes.each do |flash_name|
        # Note: Assumption that duplicate flashes are ignored when submitted
        service.add_flash(file_number: user.ssn, flash_name: flash_name)
      rescue BGS::ShareError, BGS::PublicError => e
        log_exception_to_sentry(e)
      end
    end

    def bgs_service(user)
      external_key = user.common_name || user.email

      BGS::Services.new(
        external_uid: user.icn || user.uuid,
        external_key: external_key
      )
    end
  end
end
