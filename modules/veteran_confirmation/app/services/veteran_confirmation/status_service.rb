# frozen_string_literal: true

module VeteranConfirmation
  class StatusService
    CONFIRMED = 'confirmed'
    NOT_CONFIRMED = 'not confirmed'

    def get_by_attributes(attributes)
      mvi_resp = MVI::Service.new.find_profile_from_attributes(attributes)
      return NOT_CONFIRMED unless mvi_resp.ok?

      emis_resp = EMIS::VeteranStatusService.new.get_veteran_status(edipi: mvi_resp.profile.edipi)
      return NOT_CONFIRMED if emis_resp.error?

      emis_resp.items.first.title38_status_code == 'V1' ? CONFIRMED : NOT_CONFIRMED
    end
  end
end
