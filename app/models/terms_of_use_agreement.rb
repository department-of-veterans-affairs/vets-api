# frozen_string_literal: true

class TermsOfUseAgreement < ApplicationRecord
  CURRENT_VERSION = Settings.terms_of_use.current_version

  belongs_to :user_account

  validates :agreement_version, :response, presence: true
  enum response: { declined: 0, accepted: 1 }

  scope :current, -> { where(agreement_version: CURRENT_VERSION) }
end
