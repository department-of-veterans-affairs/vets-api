# frozen_string_literal: true

class SchoolCertifyingOfficialsMailer < TransactionalEmailMailer
  SUBJECT = 'Applicant for VA Rogers STEM Scholarship'
  GA_CAMPAIGN_NAME = 'school-certifying-officials-10203-submission-notification'
  GA_DOCUMENT_PATH = '/email/form'
  GA_LABEL = 'school-certifying-officials-10203-submission-notification'
  TEMPLATE = 'school_certifying_officials'

  def build(claim_id, recipients, ga_client_id)
    @applicant = SavedClaim::EducationBenefits::VA10203.find(claim_id).open_struct_form
    super(recipients, ga_client_id, {})
  end
end
