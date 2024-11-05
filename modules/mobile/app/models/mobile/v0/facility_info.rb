# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    # @example create a new instance and parse incoming data
    #   Mobile::V0::Adapters::FacilityInfo.new(info_hash)
    #
    class FacilityInfo < Common::Resource
      attribute :id, Types::String
      attribute :facilities, Types::Array do
        attribute :id, Types::String
        attribute :name, Types::String
        attribute :city, Types::String
        attribute :state, Types::String
        attribute :cerner, Types::Bool
        attribute :miles, Types::Float.optional
      end
    end
  end
end
