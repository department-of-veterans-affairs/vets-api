# frozen_string_literal: true

require 'accredited_representation/constants'

class AccreditedIndividual < ApplicationRecord
  # Represents an accredited individual (attorney, claims agent, representative) as defined by he OGC accreditation
  # APIs. Until a form of soft deletion is implemented, these records will only reflect individuals with active
  # accreditation.
  #
  # Key notes:
  # 1. The core record attributes are populated from the OGC accreditation APIs, not the files found at
  #   https://www.va.gov/ogc/apps/accreditation/ that Veteran::Service::Representative uses.
  # 2. The intent of raw_address is to store the address as supplied by OGC for diffing purposes to avoid excess API
  #   calls. Those addresses are not verified and do not contain latitude and longitude. The address information stored
  #   on the record comes from the Lighthouse Address  Validation API so that geolocation searching is supported
  #   for the Find A Representative feature.
  # 3. The representative type should not have a POA code assigned. Representatives should only be associated with the
  #   POA codes of the AccreditedOrganizations they are accredited with.
  # 4. Attorneys and claims agents should have a POA code and should not be accredited with any AccreditedOrganization
  # 5. The ogc_id is the id from the source table within OGC. It can be used to interact with their show endpoints
  #   and may be nice to have for troubleshooting purposes.

  has_many :accreditations, dependent: :destroy
  has_many :accredited_organizations, through: :accreditations

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
