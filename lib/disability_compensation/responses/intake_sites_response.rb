# frozen_string_literal: true

module DisabilityCompensation
  module ApiProvider

    class SeparationLocation
      include ActiveModel::Serialization
      include Virtus.model

      attribute :code, Integer
      attribute :description, String
    end

    class IntakeSitesResponse
      include ActiveModel::Serialization
      include Virtus.model

      attribute :separation_locations, Array[DisabilityCompensation::ApiProvider::SeparationLocation]
    end
  end
end