# frozen_string_literal: true

module AccreditedRepresentativePortal
  class UserAccountAccreditedIndividual < ApplicationRecord
    enum(
      :power_of_attorney_holder_type,
      PowerOfAttorneyHolder::Types::ALL.index_by(&:itself),
      validate: true
    )

    validates :accredited_individual_registration_number, presence: true
    validates :user_account_email, presence: true,
                                   format: { with: URI::MailTo::EMAIL_REGEXP }

    class << self
      ##
      # Lookup registrations by email.
      # But also... track/reconcile ICN as a convenient side-effect!
      #
      def for_user_account_email(user_account_email, user_account_icn:)
        transaction do
          set_sql = [
            %(
              user_account_icn =
                CASE WHEN user_account_email = :user_account_email THEN
                  :user_account_icn
                END
            ),
            {
              user_account_email:,
              user_account_icn:
            }
          ]

          rel = where(user_account_email:).or(where(user_account_icn:))
          rel.update_all(sanitize_sql_for_assignment(set_sql)) # rubocop:disable Rails/SkipsModelValidations
          where(user_account_email:)
        end
      end
    end
  end
end
