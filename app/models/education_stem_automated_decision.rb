# frozen_string_literal: true

class EducationStemAutomatedDecision < ApplicationRecord
  INIT = 'init'
  PROCESSED = 'processed'
  DENIED = 'denied'

  DECISION_STATES = [INIT, PROCESSED, DENIED].freeze

  has_kms_key
  has_encrypted :auth_headers_json, key: :kms_key, **lockbox_options

  validates(:automated_decision_state, inclusion: DECISION_STATES)

  belongs_to(:education_benefits_claim, inverse_of: :education_stem_automated_decision)
  belongs_to(:user_account, dependent: nil, optional: false)

  def self.init
    where(automated_decision_state: INIT)
  end

  def self.processed
    where(automated_decision_state: PROCESSED)
  end

  def self.denied
    where(automated_decision_state: DENIED)
  end

  # @return [Hash] parsed auth headers
  #
  def auth_headers
    return nil if auth_headers_json.nil?

    @auth_headers_hash ||= JSON.parse(auth_headers_json)
  end
end
