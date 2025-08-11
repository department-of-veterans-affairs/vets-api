# frozen_string_literal: true

require 'accredited_representation/constants'

class AccreditedOrganization < ApplicationRecord
  # Represents an accredited organization as defined by the OGC accreditation APIs. Until a form of soft deletion is
  # implemented, these records will only reflect organization with active accreditation.
  #
  # Key notes:
  # 1. The core record attributes are populated from the OGC accreditation APIs, not the files found at
  #   https://www.va.gov/ogc/apps/accreditation/ that Veteran::Service::Organization uses.
  # 2. The intent of raw_address is to store the address as supplied by OGC for diffing purposes to avoid excess API
  #   calls. Those addresses are not verified and do not contain latitude and longitude. The address information stored
  #   on the record comes from the Lighthouse Address Validation API so that geolocation searching is supported
  #   for the Find A Representative feature.
  # 3. The ogc_id is the id from the source table within OGC. It can be used to interact with their show endpoints
  #   and may be nice to have for troubleshooting purposes.

  has_many :accreditations, dependent: :destroy
  has_many :accredited_individuals, through: :accreditations

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
    query = 'ST_DWithin(ST_SetSRID(ST_MakePoint(:long, :lat), 4326)::geography,' \
            'accredited_organizations.location, :max_distance)'
    params = { long:, lat:, max_distance: }

    where(query, params)
  end

  # return all registration_numbers associated with the organization
  #
  # @return [Array<String>]
  def registration_numbers
    accredited_individuals.pluck(:registration_number)
  end

  # This method needs to exist on the model so [Common::Collection] doesn't blow up when trying to paginate
  def self.max_per_page
    AccreditedRepresentation::Constants::MAX_PER_PAGE
  end
end
