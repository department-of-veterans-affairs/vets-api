# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module CheckIn
      class UpdateDemographics < Common::Resource
        attribute :id, Types::String
        attribute :contactNeedsUpdate, Types::Bool
        attribute :emergencyContactNeedsUpdate, Types::Bool
        attribute :nextOfKinNeedsUpdate, Types::Bool
      end
    end
  end
end
