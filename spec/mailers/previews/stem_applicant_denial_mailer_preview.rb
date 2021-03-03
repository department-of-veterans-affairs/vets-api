# frozen_string_literal: true

class StemApplicantDenialMailerPreview < ActionMailer::Preview
  def build
    return unless FeatureFlipper.staging_email?

    claim = EducationBenefitsClaim.processed.joins(:education_stem_automated_decision).includes(:saved_claim).where(
      saved_claims: {
        form_id: '22-10203'
      },
      education_stem_automated_decisions: {
        automated_decision_state: EducationStemAutomatedDecision::DENIED
      }
    )&.last
    StemApplicantDenialMailer.build(claim, nil) if claim.present?
  end
end
