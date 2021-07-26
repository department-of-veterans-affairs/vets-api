# frozen_string_literal: true

require 'csv'

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Representative < ApplicationRecord
      BASE_URL = 'https://www.va.gov/ogc/apps/accreditation/'

      self.primary_key = :representative_id

      attr_encrypted(:ssn, key: Settings.db_encryption_key)
      attr_encrypted(:dob, key: Settings.db_encryption_key)

      scope :attorneys, -> { where(user_types: ['attorney']) }
      scope :veteran_service_officers, -> { where(user_types: ['veteran_service_officer']) }
      scope :claim_agents, -> { where(user_types: ['claim_agents']) }

      validates :poa_codes, presence: true

      #
      # Find all representatives that matches the provided search criteria
      # @param first_name: [String] First name to search for, ignoring case
      # @param last_name: [String] Last name to search for, ignoring case
      # @param ssn: nil [String] SSN to search for
      # @param dob: nil [String] Date of birth to search for
      #
      # @return [Array(Veteran::Service::Representative)] All representatives found using the submitted search criteria
      def self.all_for_user(first_name:, last_name:, ssn: nil, dob: nil)
        reps = where('lower(first_name) = ? AND lower(last_name) = ?', first_name.downcase, last_name.downcase)

        reps.select do |rep|
          matching_ssn(rep, ssn) &&
            matching_date_of_birth(rep, dob)
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
        reps = all_for_user(first_name: first_name, last_name: last_name, ssn: ssn, dob: dob)
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
    end
  end
end
