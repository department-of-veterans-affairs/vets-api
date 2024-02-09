# frozen_string_literal: true

require 'csv'

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Representative < ApplicationRecord
      BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

      self.primary_key = :representative_id
      has_kms_key
      has_encrypted :dob, :ssn, key: :kms_key, **lockbox_options

      scope :attorneys, -> { where(user_types: ['attorney']) }
      scope :veteran_service_officers, -> { where(user_types: ['veteran_service_officer']) }
      scope :claim_agents, -> { where(user_types: ['claim_agents']) }

      validates :poa_codes, presence: true

      before_save :set_full_name

      #
      # Find all representatives that matches the provided search criteria
      # @param first_name: [String] First name to search for, ignoring case
      # @param last_name: [String] Last name to search for, ignoring case
      # @param ssn: nil [String] SSN to search for
      # @param dob: nil [String] Date of birth to search for
      #
      # @return [Array(Veteran::Service::Representative)] All representatives found using the submitted search criteria
      def self.all_for_user(first_name:, last_name:, ssn: nil, dob: nil, middle_initial: nil)
        reps = where('lower(first_name) = ? AND lower(last_name) = ?', first_name.downcase, last_name.downcase)

        reps.select do |rep|
          matching_ssn(rep, ssn) &&
            matching_date_of_birth(rep, dob) &&
            matching_middle_initial(rep, middle_initial)
        end
      end

      #
      # Find first representative that matches the provided search criteria
      # @param first_name: [String] First name to search for, ignoring case
      # @param last_name: [String] Last name to search for, ignoring case
      # @param ssn: nil [String] SSN to search for
      # @param dob: nil [String] Date of birth to search for
      #
      # @return [Veteran::Service::Representative] First representative record found using the submitted search criteria
      def self.for_user(first_name:, last_name:, ssn: nil, dob: nil)
        reps = all_for_user(first_name:, last_name:, ssn:, dob:)
        return nil if reps.blank?

        reps.first
      end

      #
      # Determine if representative ssn matches submitted ssn search query
      # @note Assumes that the consumer did not submit an ssn value if the value is blank
      # @param rep [Veteran::Service::Representative] Representative to match soon with
      # @param ssn [String] Submitted ssn to match against representative
      #
      # @return [Boolean] True if matches, false if not
      def self.matching_ssn(rep, ssn)
        return true if ssn.blank?

        rep.ssn.present? && rep.ssn == ssn
      end

      #
      # Determine if representative dob matches submitted birth_date search query
      # @note Assumes that the consumer did not submit a birth_date value if the value is blank
      # @param rep [Veteran::Service::Representative] Representative to match soon with
      # @param birth_date [String] Submitted birth_date to match against representative
      #
      # @return [Boolean] True if matches, false if not
      def self.matching_date_of_birth(rep, birth_date)
        return true if birth_date.blank?

        rep.dob.present? && rep.dob == birth_date
      end

      #
      # Determine if representative middle initial matches submitted middle_initial search query
      # @note Assumes that the consumer did not submit a middle_initial value if the value is blank
      # @param rep [Veteran::Service::Representative] Representative to match soon with
      # @param middle_initial [String] Submitted middle_initial to match against representative
      #
      # @return [Boolean] True if matches, false if not
      def self.matching_middle_initial(rep, middle_initial)
        return true if middle_initial.blank?

        rep.middle_initial.present? && rep.middle_initial == middle_initial
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

      #
      # Set the full_name attribute for the representative
      def set_full_name
        self.full_name = "#{first_name} #{last_name}"
      end

      def self.max_per_page
        Constants::MAX_PER_PAGE
      end
    end
  end
end
