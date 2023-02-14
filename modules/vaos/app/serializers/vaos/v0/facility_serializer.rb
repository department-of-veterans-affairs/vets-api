# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'fast_jsonapi'

module VAOS
  module V0
    class FacilitySerializer
      include FastJsonapi::ObjectSerializer

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
# :nocov:
