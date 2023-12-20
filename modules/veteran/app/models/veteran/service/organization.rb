# frozen_string_literal: true

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Organization < ApplicationRecord
      self.primary_key = :poa

      validates :poa, presence: true

      #
      # Find all organizations that are located within a distance of a specific location
      # @params long [Float] longitude of the location of interest
      # @param lat [Float] latitude of the location of interest
      # @param max_distance [Float] the maximum search distance in meters
      #
      # @return [Veteran::Service::Organization::ActiveRecord_Relation] an ActiveRecord_Relation of
      #   all organizations matching the search criteria
      def self.find_within_max_distance(long, lat, max_distance = Constants::DEFAULT_MAX_DISTANCE)
        query = 'ST_DWithin(ST_SetSRID(ST_MakePoint(:long, :lat), 4326)::geography, location, :max_distance)'
        params = { long:, lat:, max_distance: }

        where(query, params)
      end

      def self.max_per_page
        Constants::MAX_PER_PAGE
      end
    end
  end
end
