# frozen_string_literal: true

module TravelPay
  class ComplexClaimsFormChoice < ApplicationRecord
    self.table_name = 'travel_pay_complex_claims_form_choices'

    belongs_to :complex_claims_form_session, class_name: 'TravelPay::ComplexClaimsFormSession',
                                             foreign_key: 'travel_pay_complex_claims_form_session_id',
                                             inverse_of: :complex_claims_form_choices

    validates :expense_type, presence: true
    validates :expense_type, uniqueness: { scope: :travel_pay_complex_claims_form_session_id }

    VALID_EXPENSE_TYPES = %w[mileage parking toll].freeze
    validates :expense_type, inclusion: { in: VALID_EXPENSE_TYPES }

    def to_progress_hash
      {
        expenseType: expense_type,
        formProgress: form_progress || []
      }
    end

    def update_form_step(step_id, started: false, complete: false)
      current_progress = form_progress || []
      updated_progress = current_progress.reject { |step| step['id'] == step_id }
      updated_progress << { 'id' => step_id, 'started' => started, 'complete' => complete }

      update!(form_progress: updated_progress.sort_by { |step| step['id'] })
    end

    def mark_step_started(step_id)
      update_form_step(step_id, started: true, complete: false)
    end

    def mark_step_complete(step_id)
      update_form_step(step_id, started: true, complete: true)
    end

    def step_status(step_id)
      step = form_progress&.find { |s| s['id'] == step_id }
      return { started: false, complete: false } unless step

      { started: step['started'], complete: step['complete'] }
    end
  end
end
