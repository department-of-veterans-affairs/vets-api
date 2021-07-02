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

      def self.all_for_user(first_name:, last_name:, ssn: nil, dob: nil, poa_code: nil)
        reps = where('lower(first_name) = ? AND lower(last_name) = ?', first_name.downcase, last_name.downcase)

        reps.select do |rep|
          matching_ssn(rep, ssn) &&
            matching_date_of_birth(rep, dob) &&
            matching_poa_code(rep, poa_code)
        end
      end

      def self.for_user(first_name:, last_name:, ssn: nil, dob: nil, poa_code: nil)
        reps = all_for_user(first_name: first_name, last_name: last_name, ssn: ssn, dob: dob, poa_code: poa_code)
        return nil if reps.blank?

        reps.first
      end

      def self.matching_ssn(rep, ssn)
        return true if ssn.blank?

        rep.ssn.present? && rep.ssn == ssn
      end

      def self.matching_date_of_birth(rep, birth_date)
        return true if birth_date.blank?

        rep.dob.present? && rep.dob == birth_date
      end

      def self.matching_poa_code(rep, poa_code)
        return true if poa_code.blank?

        rep.poa_codes.present? && rep.poa_codes.include?(poa_code)
      end
    end
  end
end
