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

    RECONCILE_ASSIGNMENT_SQL_TEMPLATE = <<~SQL
      user_account_icn =
        CASE when user_account_email = :user_account_email THEN
          :user_account_icn
        END
    SQL

    class << self
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
              user_account_email:,
              user_account_icn:
            ])

          update_rel.update_all(assignment_sql)
          find_by(user_account_icn:)
        end
      end
    end
  end
end
