# frozen_string_literal: true

require 'ostruct'
require 'emis/veteran_status_service'

module VeteranConfirmation
  class StatusService
    CONFIRMED = 'confirmed'
    NOT_CONFIRMED = 'not confirmed'

    def get_by_attributes(user_attributes)
      attrs = UserIdentity.new(user_attributes.merge(uuid: SecureRandom.uuid, loa: { current: 3, highest: 3 }))
      mvi_resp = MPI::Service.new.find_profile(attrs)
      return NOT_CONFIRMED if mvi_resp.not_found?
      raise mvi_resp.error unless mvi_resp.ok?

      if Settings.vet_verification.mock_emis == true
        Rails.logger.info("Settings.vet_verification.mock_emis: #{Settings.vet_verification.mock_emis}")
        veteran_status_service = EMIS::MockVeteranStatusService.new
      else
        veteran_status_service = EMIS::VeteranStatusService.new
      end

      Rails.logger.info("Service type: #{veteran_status_service}")
      emis_resp = veteran_status_service.get_veteran_status(edipi_or_icn_option(mvi_resp.profile))
      return NOT_CONFIRMED if emis_resp.error?

      emis_resp.items.first&.title38_status_code == 'V1' ? CONFIRMED : NOT_CONFIRMED
    end

    private

    def edipi_or_icn_option(profile)
      if profile.edipi.present?
        { edipi: profile.edipi }
      else
        { icn: profile.icn }
      end
    end
  end
end
