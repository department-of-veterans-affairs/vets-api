# frozen_string_literal: true

require 'accredited_representation/constants'

class AccreditedIndividual < ApplicationRecord
  # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :accredited_organizations,
                          class: 'AccreditedOrganization',
                          join_table: 'accredited_individuals_accredited_organizations'

  # rubocop:enable Rails/HasAndBelongsToMany

  validates :ogc_id, :registration_number, :individual_type, presence: true
  validates :poa_code, length: { is: 3 }, allow_blank: true
  validates :individual_type, uniqueness: { scope: :registration_number }

  enum individual_type: {
    'attorney' => 'attorney',
    'claims_agent' => 'claims_agent',
    'representative' => 'representative'
  }

  # Find all [AccreditedIndividuals] that are located within a distance of a specific location
  # @param long [Float] longitude of the location of interest
  # @param lat [Float] latitude of the location of interest
  # @param max_distance [Float] the maximum search distance in meters
  #
  # @return [AccreditedIndividual::ActiveRecord_Relation] an ActiveRecord_Relation of
  #   all individuals matching the search criteria
  def self.find_within_max_distance(long, lat, max_distance = AccreditedRepresentation::Constants::DEFAULT_MAX_DISTANCE)
    query = 'ST_DWithin(ST_SetSRID(ST_MakePoint(:long, :lat), 4326)::geography, location, :max_distance)'
    params = { long:, lat:, max_distance: }

    where(query, params)
  end

  # return all poa_codes associated with the individual
  #
  # @return [Array<String>]
  def poa_codes
    ([poa_code] + accredited_organizations.pluck(:poa_code)).compact
  end
end
