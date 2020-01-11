# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class InstitutionSerializer
    include FastJsonapi::ObjectSerializer

    set_id :institution_ien
    attributes :location_ien,
               :institution_sid,
               :institution_ien,
               :institution_name,
               :institution_code
  end
end
