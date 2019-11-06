# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class FacilitySerializer
    include FastJsonapi::ObjectSerializer

    set_id :unique_id
    attributes :institution_code
               :city
               :state_abbrev
               :authoritative_name
               :root_station_code
               :admin_parent
               :parent_station_code
  end
end
