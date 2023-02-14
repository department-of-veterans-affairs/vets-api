# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

module VAOS
  module V0
    class ClinicInstitutionSerializer
      include FastJsonapi::ObjectSerializer

      set_id :location_ien
      attributes :location_ien,
                 :institution_sid,
                 :institution_ien,
                 :institution_name,
                 :institution_code
    end
  end
end
# :nocov:
