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

      #
      # Find all organizations with a name with at least the FUZZY_SEARCH_THRESHOLD value of
      #   word similarity. This gives us a way to fuzzy search for names.
      # @param search_phrase [String] the word, words, or phrase we want organizations with names similar to
      #
      # @return [Veteran::Service::Organization::ActiveRecord_Relation] an ActiveRecord_Relation of
      #   all organizations matching the search criteria
      def self.find_with_name_similar_to(search_phrase)
        where('word_similarity(?, name) >= ?', search_phrase, Constants::FUZZY_SEARCH_THRESHOLD)
      end

      def self.max_per_page
        Constants::MAX_PER_PAGE
      end
    end
  end
end
