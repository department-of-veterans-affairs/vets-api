# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class SystemPactSerializer
    include FastJsonapi::ObjectSerializer

    set_id :provider_sid
    attributes :unique_id,
               :facility_id,
               :possible_primary,
               :provider_position,
               :provider_sid,
               :staff_name,
               :team_name,
               :team_purpose,
               :team_sid,
               :title
  end
end
