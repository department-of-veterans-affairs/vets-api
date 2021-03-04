# frozen_string_literal: true

class StemApplicantDenialMailerPreview < ActionMailer::Preview
  def build
    return unless FeatureFlipper.staging_email?

    time = Time.zone.now
    claim = EducationBenefitsClaim.includes(:saved_claim, :education_stem_automated_decision).where(
      processed_at: (time - 24.hours)..time,
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
