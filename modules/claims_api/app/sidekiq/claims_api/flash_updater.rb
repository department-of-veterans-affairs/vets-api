# frozen_string_literal: true

require 'bgs_service/claimant_web_service'
module ClaimsApi
  class FlashUpdater < UpdaterService
    def perform(flashes, auto_claim_id)
      user = bgs_headers(auto_claim_id)

      flashes.each do |flash_name|
        # NOTE: Assumption that duplicate flashes are ignored when submitted
        add_flash(user, flash_name)
      rescue BGS::ShareError, BGS::PublicError => e
        persist_exception(e, auto_claim_id:)
      end

      assigned_flashes = bgs_service(user).find_assigned_flashes(user['ssn'])[:flashes]
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

    def add_flash(user, flash_name)
      if Flipper.enabled? :claims_api_flash_updater_uses_local_bgs
        bgs_service(user).add_flash(file_number: user['ssn'], flash: { flash_name: })
      else
        bgs_service(user).add_flash(file_number: user['ssn'], flash_name:)
      end
    end

    def bgs_service(user)
      if Flipper.enabled? :claims_api_flash_updater_uses_local_bgs
        claimant_service(user)
      else
        bgs_ext_service(user).claimant
      end
    end

    def claimant_service(user)
      ClaimsApi::ClaimantWebService.new(
        external_uid: user['ssn'],
        external_key: user['ssn']
      )
    end

    def bgs_ext_service(user)
      BGS::Services.new(
        external_uid: user['ssn'],
        external_key: user['ssn']
      )
    end
  end
end
