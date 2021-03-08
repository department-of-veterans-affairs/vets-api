# frozen_string_literal: true

class StemApplicantDenialMailer < TransactionalEmailMailer
  SUBJECT = "We've reached a decision on your STEM Scholarship application"
  GA_CAMPAIGN_NAME = 'stem_applicant_denial-10203-submission-notification'
  GA_DOCUMENT_PATH = '/email/form'
  GA_LABEL = 'stem-applicant-denial-10203-submission-notification'
  TEMPLATE = 'stem_applicant_denial'

  def application_date
    @claim.saved_claim.created_at.strftime('%b %d, %Y')
  end

  def your_claims_status_url
    env = FeatureFlipper.staging_email? ? 'stage.' : ''
    "https://#{env}va.gov/track-claims/your-stem-claims/#{@claim.id}/status"
  end

  def build(claim, ga_client_id)
    @applicant = claim.saved_claim.open_struct_form
    @claim = claim

    super([@applicant.email], ga_client_id, {})
  end
end
