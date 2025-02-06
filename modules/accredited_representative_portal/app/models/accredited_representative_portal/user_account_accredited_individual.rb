# frozen_string_literal: true

# rubocop:disable Rails/I18nLocaleTexts
module AccreditedRepresentativePortal
  class UserAccountAccreditedIndividual < ApplicationRecord
    enum power_of_attorney_holder_type: {
      veteran_service_organization: 'veteran_service_organization'
      # Future supported types (commented for documentation):
      # attorney: 'attorney',
      # claims_agent: 'claims_agent',
    }

    validates :accredited_individual_registration_number, presence: true
    validates :user_account_email, presence: true,
                                   format: { with: URI::MailTo::EMAIL_REGEXP, message: 'invalid email format' }
  end
end
# rubocop:enable Rails/I18nLocaleTexts
