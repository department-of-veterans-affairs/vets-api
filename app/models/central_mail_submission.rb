class CentralMailSubmission < ActiveRecord::Base
  belongs_to(:central_mail_claim, inverse_of: :central_mail_submission, foreign_key: 'saved_claim_id')

  validates(:state, presence: true, inclusion: %w[success failed pending])
  validates(:central_mail_claim, presence: true)
end
