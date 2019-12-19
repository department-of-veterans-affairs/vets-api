# frozen_string_literal: true

require 'ostruct'

module VeteranConfirmation
  class StatusService
    CONFIRMED = 'confirmed'
    NOT_CONFIRMED = 'not confirmed'

    def get_by_attributes(user_attributes)
      attrs = OpenStruct.new(user_attributes)
      mvi_resp = MVI::AttrService.new.find_profile(attrs)
      return NOT_CONFIRMED unless mvi_resp.ok?

      emis_resp = EMIS::VeteranStatusService.new.get_veteran_status(
        edipi: mvi_resp.profile.edipi,
        icn: mvi_resp.profile.icn
      )
      return NOT_CONFIRMED if emis_resp.error?

      emis_resp.items.first.title38_status_code == 'V1' ? CONFIRMED : NOT_CONFIRMED
    end
  end
end
