# frozen_string_literal: true

class StemApplicantScoMailer < TransactionalEmailMailer
  SUBJECT = 'Outreach to School Certifying Official for VA Rogers STEM Scholarship'
  GA_CAMPAIGN_NAME = 'school-certifying-officials-10203-submission-notification'
  GA_DOCUMENT_PATH = '/email/form'
  GA_LABEL = 'school-certifying-officials-10203-submission-notification'
  TEMPLATE = 'stem_applicant_sco'

  def build(claim_id, ga_client_id)
    @applicant = SavedClaim::EducationBenefits::VA10203.find(claim_id).open_struct_form
    super([@applicant.email], ga_client_id, {})
  end
end
