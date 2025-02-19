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
  end
end
