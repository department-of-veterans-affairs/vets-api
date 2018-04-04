class CentralMailClaim < SavedClaim
  has_one(:central_mail_submission, inverse_of: :central_mail_claim, foreign_key: 'saved_claim_id')

  before_create(:build_central_mail_submission)
end
