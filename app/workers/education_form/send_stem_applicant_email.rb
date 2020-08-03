# frozen_string_literal: true

module EducationForm
  class SendStemApplicantEmail
    include Sidekiq::Worker

    def perform(user_uuid, claim_id)
      @user = User.find(user_uuid)
      claim = SavedClaim::EducationBenefits::VA10203.find(claim_id)
      StemApplicantConfirmationMailer.build(claim).deliver_now
    end
  end
end
