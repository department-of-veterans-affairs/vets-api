# frozen_string_literal: true

class StemApplicantConfirmationMailerPreview < ActionMailer::Preview
  def build
    return unless FeatureFlipper.staging_email?

    claim = SavedClaim::EducationBenefits::VA10203.last
    ga_client_id = nil
    StemApplicantConfirmationMailer.build(claim, ga_client_id) if claim.present?
  end
end
