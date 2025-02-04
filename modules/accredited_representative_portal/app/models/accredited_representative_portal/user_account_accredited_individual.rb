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
    validates :power_of_attorney_holder_type, presence: true, inclusion: {
      in: power_of_attorney_holder_types.keys,
      message: 'must be: veteran_service_organization'
    }
    validates :user_account_email, presence: true,
                                   format: { with: /\A[^@\s]+@[^@\s]+\z/, message: 'invalid email format' }
  end
end
# rubocop:enable Rails/I18nLocaleTexts
