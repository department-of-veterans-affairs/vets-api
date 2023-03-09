# frozen_string_literal: true

module VAOS
  module V2
    class SchedulingConfigurationSerializer
      include JSONAPI::Serializer

      set_id :facility_id

      set_type :scheduling_configuration

      attributes :facility_id,
                 :services,
                 :community_care
    end
  end
end
