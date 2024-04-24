# frozen_string_literal: true

require 'accredited_representation/constants'

class AccreditedOrganization < ApplicationRecord
  # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :accredited_individuals,
                          class: 'AccreditedIndividual',
                          join_table: 'accredited_individuals_accredited_organizations'
  # rubocop:enable Rails/HasAndBelongsToMany

  validates :ogc_id, :poa_code, presence: true
  validates :poa_code, length: { is: 3 }
  validates :poa_code, uniqueness: true

  #
  # Find all [AccreditedOrganizations] that are located within a distance of a specific location
  # @param long [Float] longitude of the location of interest
  # @param lat [Float] latitude of the location of interest
  # @param max_distance [Float] the maximum search distance in meters
  #
  # @return [AccreditedOrganization::ActiveRecord_Relation] an ActiveRecord_Relation of
  #   all organizations matching the search criteria
  def self.find_within_max_distance(long, lat, max_distance = AccreditedRepresentation::Constants::DEFAULT_MAX_DISTANCE)
    query = 'ST_DWithin(ST_SetSRID(ST_MakePoint(:long, :lat), 4326)::geography, location, :max_distance)'
    params = { long:, lat:, max_distance: }

    where(query, params)
  end

  # return all registration_numbers associated with the individual
  #
  # @return [Array<String>]
  def registration_numbers
    accredited_individuals.pluck(:registration_number)
  end
end
