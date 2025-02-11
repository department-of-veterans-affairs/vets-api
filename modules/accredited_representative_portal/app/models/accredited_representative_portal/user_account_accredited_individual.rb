# frozen_string_literal: true

module AccreditedRepresentativePortal
  class UserAccountAccreditedIndividual < ApplicationRecord
    enum :power_of_attorney_holder_type, {
      ##
      # Future supported types:
      # attorney: 'attorney',
      # claims_agent: 'claims_agent',
      #
      veteran_service_organization: 'veteran_service_organization'
    }, validate: true

    validates :accredited_individual_registration_number, presence: true
    validates :user_account_email, presence: true,
                                   format: { with: URI::MailTo::EMAIL_REGEXP }

    # Syncs VSO registrations with user's VA identity and returns authorized registration numbers.
    # For users with VA credentials (email/ICN), this:
    # 1. Links their ICN to matching email records
    # 2. Removes any existing ICN links from non-matching records
    # 3. Returns registration numbers for authorized VSO associations
    #
    # @param email [String] VA email address
    # @param icn [String] VA Identity Control Number
    # @return [Array<String>] List of authorized VSO registration numbers
    #
    def self.authorize_vso_representative!(email:, icn:)
      records = where(user_account_email: email).or(where(user_account_icn: icn))

      records.each_with_object([]) do |record, registration_numbers|
        if record.user_account_email == email
          record.user_account_icn = icn
          registration_numbers << record.accredited_individual_registration_number if record.save
        else
          record.user_account_icn = nil
          record.save
        end
      end
    end
  end
end
