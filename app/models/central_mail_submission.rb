# frozen_string_literal: true

class CentralMailSubmission < ApplicationRecord
  belongs_to(:central_mail_claim, inverse_of: :central_mail_submission, foreign_key: 'saved_claim_id')

  validates(:state, presence: true, inclusion: %w[success failed pending])
end
