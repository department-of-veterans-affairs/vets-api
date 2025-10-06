# frozen_string_literal: true

module TravelPay
  class ComplexClaimsFormSession < ApplicationRecord
    self.table_name = 'travel_pay_complex_claims_form_sessions'

    has_many :complex_claims_form_choices,
             class_name: 'TravelPay::ComplexClaimsFormChoice',
             foreign_key: 'travel_pay_complex_claims_form_session_id',
             dependent: :destroy,
             inverse_of: :complex_claims_form_session

    validates :user_icn, presence: true

    def self.find_or_create_for_user(user_icn)
      find_or_create_by(user_icn:)
    end

    def to_progress_json
      {
        choices: complex_claims_form_choices.order(:expense_type).map(&:to_progress_hash)
      }
    end

    def update_form_step(expense_type, step_id, started: false, complete: false)
      choice = find_or_create_choice(expense_type)
      choice.update_form_step(step_id, started:, complete:)
    end

    private

    def find_or_create_choice(expense_type)
      complex_claims_form_choices.find_or_create_by(expense_type:)
    end
  end
end
