# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module ClaimsApi
  class FlashUpdater < UpdaterService
    include Sidekiq::Worker
    include SentryLogging

    def perform(flashes, auto_claim_id)
      user = bgs_headers(auto_claim_id)
      service = bgs_service(user).claimant

      flashes.each do |flash_name|
        # NOTE: Assumption that duplicate flashes are ignored when submitted
        service.add_flash(file_number: user['ssn'], flash_name:)
      rescue BGS::ShareError, BGS::PublicError => e
        persist_exception(e, auto_claim_id:)
      end

      assigned_flashes = service.find_assigned_flashes(user['ssn'])[:flashes]
      flashes.each do |flash_name|
        assigned_flash = assigned_flashes.find { |af| af[:flash_name].strip == flash_name }
        if assigned_flash.blank?
          e = StandardError.new("Failed to assign '#{flash_name}' to Veteran")
          persist_exception(e, auto_claim_id:, message: { text: e.message })
        end
      end
    end

    def persist_exception(e, auto_claim_id: nil, message: { key: e.code, text: e.message })
      if auto_claim_id.present?
        auto_claim = ClaimsApi::AutoEstablishedClaim.find(auto_claim_id)
        auto_claim.bgs_flash_responses = [] if auto_claim.bgs_flash_responses.blank?
        auto_claim.bgs_flash_responses = auto_claim.bgs_flash_responses + [message]
        auto_claim.save
      end
      log_exception_to_sentry(e)
    end

    def bgs_service(user)
      BGS::Services.new(
        external_uid: user['ssn'],
        external_key: user['ssn']
      )
    end
  end
end
