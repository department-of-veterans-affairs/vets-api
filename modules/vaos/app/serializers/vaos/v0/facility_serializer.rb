# frozen_string_literal: true

require 'jsonapi/serializer'

module VAOS
  module V0
    class FacilitySerializer
      include JSONAPI::Serializer

      set_id :institution_code
      attributes :institution_code,
                 :city,
                 :state_abbrev,
                 :authoritative_name,
                 :root_station_code,
                 :admin_parent,
                 :parent_station_code
    end
  end
end
