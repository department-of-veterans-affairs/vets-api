# frozen_string_literal: true

require 'csv'

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Representative < ApplicationRecord
      include RepresentationManagement::Geocodable

      BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

      self.primary_key = :representative_id

      scope :attorneys, -> { where(user_types: ['attorney']) }
      scope :veteran_service_officers, -> { where(user_types: ['veteran_service_officer']) }
      scope :claim_agents, -> { where(user_types: ['claim_agents']) }

      validates :poa_codes, presence: true

      before_save :set_full_name

      #
      # Find all representatives that matches the provided search criteria
      # @param first_name: [String] First name to search for, ignoring case
      # @param last_name: [String] Last name to search for, ignoring case
      # @param middle_initial: nil [String] Middle initial to search for
      # @param poa_code: nil [String] filter to reps working this POA code
      #
      # @return [Array(Veteran::Service::Representative)] All representatives found using the submitted search criteria
      def self.all_for_user(first_name:, last_name:, middle_initial: nil, poa_code: nil)
        return [] if first_name.nil? || last_name.nil?

        representatives = where('lower(first_name) = ? AND lower(last_name) = ?', first_name&.downcase,
                                last_name&.downcase)
        representatives = representatives.where('? = ANY(poa_codes)', poa_code) if poa_code
        representatives.select { |rep| matching_middle_initial(rep, middle_initial) }
      end

      #
      # Find first representative that matches the provided search criteria
      # @param first_name: [String] First name to search for, ignoring case
      # @param last_name: [String] Last name to search for, ignoring case
      #
      # @return [Veteran::Service::Representative] First representative record found using the submitted search criteria
      def self.for_user(first_name:, last_name:)
        return nil if first_name.nil? || last_name.nil?

        representatives = all_for_user(first_name:, last_name:)
        return nil if representatives.blank?

        representatives.first
      end

      #
      # Determine if representative middle initial matches submitted middle_initial search query
      # @note Assumes that the consumer did not submit a middle_initial value if the value is blank
      # @param rep [Veteran::Service::Representative] Representative to match soon with
      # @param middle_initial [String] Submitted middle_initial to match against representative
      #
      # @return [Boolean] True if matches, false if not
      def self.matching_middle_initial(representative, middle_initial)
        return true if middle_initial.blank?

        representative.middle_initial.present? && representative.middle_initial == middle_initial
      end

      #
      # Find all representatives that are located within a distance of a specific location
      # @param long [Float] longitude of the location of interest
      # @param lat [Float] latitude of the location of interest
      # @param max_distance [Float] the maximum search distance in meters
      #
      # @return [Veteran::Service::Representative::ActiveRecord_Relation] an ActiveRecord_Relation of
      #   all representatives matching the search criteria
      def self.find_within_max_distance(long, lat, max_distance = Constants::DEFAULT_MAX_DISTANCE)
        query = 'ST_DWithin(ST_SetSRID(ST_MakePoint(:long, :lat), 4326)::geography, veteran_representatives.location, :max_distance)' # rubocop:disable Layout/LineLength
        params = { long:, lat:, max_distance: }

        where(query, params)
      end

      def organizations
        Veteran::Service::Organization.where(poa: poa_codes)
      end

      def self.max_per_page
        Constants::MAX_PER_PAGE
      end

      #
      # Set the full_name attribute for the representative
      def set_full_name
        self.full_name = if first_name.blank? && last_name.blank?
                           ''
                         elsif first_name.blank?
                           last_name
                         elsif last_name.blank?
                           first_name
                         else
                           "#{first_name} #{last_name}"
                         end
      end

      #
      # Compares rep's current info with new data to detect changes in address, email, or phone number.
      # @param rep_data [Hash] New data with :email, :phone_number, and :raw_address keys for comparison.
      #
      # @return [Hash] Hash with "email_changed", "phone_number_changed", "address_changed" keys as booleans.
      def diff(rep_data)
        {
          'email_changed' => email != rep_data[:email],
          'phone_number_changed' => phone_number != rep_data[:phone_number],
          'address_changed' => raw_address != rep_data[:raw_address]
        }
      end

      def user_type
        user_types.first
      end

      #
      # Override for Geocodable concern - uses representative_id as primary key
      # @return [String] The representative_id
      def geocoding_record_id
        representative_id
      end

      private

      # Legacy address comparison method - kept for reference but no longer used in diff
      #
      # Checks if the rep's address has changed compared to a new address hash.
      # @param other_address [Hash] New address data with keys for address components and state code.
      #
      # @return [Boolean] True if current address differs from `other_address`, false otherwise.
      def address_changed?(rep_data)
        address = [address_line1, address_line2, address_line3, city, zip_code, zip_suffix, state_code].join(' ')
        other_address = rep_data[:address]
                        .values_at(:address_line1, :address_line2, :address_line3, :city, :zip_code5, :zip_code4)
                        .push(rep_data.dig(:address, :state_province, :code))
                        .join(' ')
        address != other_address
      end
    end
  end
end
