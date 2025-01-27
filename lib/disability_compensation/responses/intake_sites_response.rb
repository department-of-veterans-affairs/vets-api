# frozen_string_literal: true

module DisabilityCompensation
  module ApiProvider
    class SeparationLocation
      include ActiveModel::Serialization
      include Virtus.model

      attribute :code, String
      attribute :description, String
    end

    class IntakeSitesResponse
      include ActiveModel::Serialization
      include Virtus.model

      attribute :separation_locations, Array[DisabilityCompensation::ApiProvider::SeparationLocation]
      attribute :status, Integer

      def cache?
        status == 200
      end
    end
  end
end
