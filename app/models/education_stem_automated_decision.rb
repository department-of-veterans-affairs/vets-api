# frozen_string_literal: true

class EducationStemAutomatedDecision < ApplicationRecord
  DECISION_STATES = %w[init processed denied].freeze

  validates(:automated_decision_state, inclusion: DECISION_STATES)

  belongs_to(:education_benefits_claim, inverse_of: :education_stem_automated_decision)
end
