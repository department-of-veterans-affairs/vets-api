# frozen_string_literal: true

class TermsOfUseAgreement < ApplicationRecord
  belongs_to :user_account

  validates :agreement_version, :response, presence: true
  enum response: { declined: 0, accepted: 1 }
end
