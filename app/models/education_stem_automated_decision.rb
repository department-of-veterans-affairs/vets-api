# frozen_string_literal: true

class EducationStemAutomatedDecision < ApplicationRecord
  DECISION_STATES = %w[init processed denied].freeze

  attr_encrypted(:auth_headers_json, key: Settings.db_encryption_key)

  validates(:automated_decision_state, inclusion: DECISION_STATES)

  belongs_to(:education_benefits_claim, inverse_of: :education_stem_automated_decision)

  def self.init
    where(automated_decision_state: 'init')
  end

  def self.processed
    where(automated_decision_state: 'processed')
  end

  def self.denied
    where(automated_decision_state: 'denied')
  end

  # @return [Hash] parsed auth headers
  #
  def auth_headers
    @auth_headers_hash ||= JSON.parse(auth_headers_json)
  end
end
