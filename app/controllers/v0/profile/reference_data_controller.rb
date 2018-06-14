# frozen_string_literal: true

module V0
  module Profile
    class ReferenceDataController < ApplicationController
      def countries
        render json: service.countries,
               serializer: CountriesSerializer
      end

      def states
        render json: service.states,
               serializer: StatesSerializer
      end

      def zipcodes
        render json: service.zipcodes,
               serializer: ZipcodesSerializer
      end

      private

      def service
        @service ||= Vet360Redis::ReferenceData.new
      end
    end
  end
end
