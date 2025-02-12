# frozen_string_literal: true

module AccreditedRepresentativePortal
  class UserAccountAccreditedIndividual < ApplicationRecord
    enum(
      :power_of_attorney_holder_type,
      PowerOfAttorneyHolder::Types::ALL.zip(PowerOfAttorneyHolder::Types::ALL).to_h,
      validate: true
    )

    validates :accredited_individual_registration_number, presence: true
    validates :user_account_email, presence: true,
                                   format: { with: URI::MailTo::EMAIL_REGEXP }

    RECONCILE_ASSIGNMENT_SQL_TEMPLATE = <<~SQL.squish
      user_account_icn =
        CASE when user_account_email = :user_account_email THEN
          :user_account_icn
        END
    SQL

    class << self
      # The `reconcile_and_find_by` method is responsible for associating a user's account information
      # based on their email and ICN.
      #
      # Why this method exists:
      # - The primary lookup we perform is from `email => registration number`, which helps determine
      #   the accredited representative associated with the logged-in user.
      # - Tracking ICNs is currently a "nice-to-have" feature rather than a core requirement.
      # - The method updates ICN tracking where applicable and removes outdated ICN associations when
      #   an email no longer matches.
      #
      # How it works:
      # - If a record exists with the given email, it updates the ICN to match the logged-in user's.
      # - If a record exists with the given ICN but the email no longer matches, it clears the ICN field
      #   to prevent incorrect associations.
      #
      # This ensures that our email-based lookup remains the primary mechanism for resolving
      # accredited representatives, while also keeping ICN tracking clean and up to date.
      #
      # rubocop:disable Rails/SkipsModelValidations
      def reconcile_and_find_by(
        user_account_email:,
        user_account_icn:
      )
        transaction do
          update_rel =
            where(user_account_email:).or(
              where(user_account_icn:)
            )

          assignment_sql =
            sanitize_sql_for_assignment([
                                          RECONCILE_ASSIGNMENT_SQL_TEMPLATE,
                                          { user_account_email:,
                                            user_account_icn: }
                                        ])

          update_rel.update_all(assignment_sql)
          find_by(user_account_icn:)
        end
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
  end
end
