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

      def self.for_user(first_name:, last_name:, ssn: nil, dob: nil)
        reps = where('lower(first_name) = ? AND lower(last_name) = ?', first_name.downcase, last_name.downcase)
        reps.each do |rep|
          if matching_ssn(rep, ssn) && matching_date_of_birth(rep, dob)
            return rep
          elsif rep.ssn.blank? && rep.dob.blank?
            return rep
          end
        end
        nil
      end

      def self.matching_ssn(rep, ssn)
        rep.ssn.present? && rep.ssn == ssn
      end

      def self.matching_date_of_birth(rep, birth_date)
        rep.dob.present? && rep.dob == birth_date
      end
    end
  end
end
