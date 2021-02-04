# frozen_string_literal: true

class StemApplicantScoMailer < TransactionalEmailMailer
  SUBJECT = 'Outreach to School Certifying Official for VA Rogers STEM Scholarship'
  GA_CAMPAIGN_NAME = 'school-certifying-officials-10203-submission-notification'
  GA_DOCUMENT_PATH = '/email/form'
  GA_LABEL = 'school-certifying-officials-10203-submission-notification'
  TEMPLATE = 'stem_applicant_sco'

  def build(applicant, ga_client_id)
    @applicant = applicant
    super([applicant.email], ga_client_id, {})
  end
end
