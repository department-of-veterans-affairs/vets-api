# frozen_string_literal: true

require 'vets/model'

module DisabilityCompensation
  module ApiProvider
    class SeparationLocation
      include Vets::Model

      attribute :code, String
      attribute :description, String
    end

    class IntakeSitesResponse
      include Vets::Model

      attribute :separation_locations, DisabilityCompensation::ApiProvider::SeparationLocation, array: true
      attribute :status, Integer

      def cache?
        status == 200
      end
    end
  end
end
