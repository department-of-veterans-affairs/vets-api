# frozen_string_literal: true

require 'jsonapi/serializer'

module VAOS
  module V0
    class ClinicInstitutionSerializer
      include JSONAPI::Serializer

      set_id :location_ien
      attributes :location_ien,
                 :institution_sid,
                 :institution_ien,
                 :institution_name,
                 :institution_code
    end
  end
end
