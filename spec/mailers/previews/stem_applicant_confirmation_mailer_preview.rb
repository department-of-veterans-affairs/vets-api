# frozen_string_literal: true

class StemApplicantConfirmationMailerPreview < ActionMailer::Preview
  def build
    return unless FeatureFlipper.staging_email?
    return unless SavedClaim::EducationBenefits::VA10203.exists?(params[:claim_id])

    claim = SavedClaim::EducationBenefits::VA10203.find(params[:claim_id])
    ga_client_id = params.key?(:ga_client_id) ? params[:ga_client_id] : nil
    StemApplicantConfirmationMailer.build(claim, ga_client_id) if claim.present?
  end
end
