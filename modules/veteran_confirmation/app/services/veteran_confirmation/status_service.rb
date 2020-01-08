# frozen_string_literal: true

require 'ostruct'

module VeteranConfirmation
  class StatusService
    CONFIRMED = 'confirmed'
    NOT_CONFIRMED = 'not confirmed'

    def get_by_attributes(user_attributes)
      attrs = OpenStruct.new(user_attributes)
      mvi_resp = AttrService.new.find_profile(attrs)
      return NOT_CONFIRMED if mvi_resp.not_found?
      raise mvi_resp.error unless mvi_resp.ok?

      emis_resp = EMIS::VeteranStatusService.new.get_veteran_status(edipi_or_icn_option(mvi_resp.profile))
      return NOT_CONFIRMED if emis_resp.error?

      emis_resp.items.first.title38_status_code == 'V1' ? CONFIRMED : NOT_CONFIRMED
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
