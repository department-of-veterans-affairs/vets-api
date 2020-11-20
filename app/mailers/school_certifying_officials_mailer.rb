# frozen_string_literal: true

class SchoolCertifyingOfficialsMailer < TransactionalEmailMailer
  SUBJECT = 'Applicant for VA Rogers STEM Scholarship'
  GA_CAMPAIGN_NAME = 'school-certifying-officials-10203-submission-notification'
  GA_DOCUMENT_PATH = '/email/form'
  GA_LABEL = 'school-certifying-officials-10203-submission-notification'
  TEMPLATE = 'school_certifying_officials'

  def build(applicant, recipients, ga_client_id)
    @applicant = applicant
    super(recipients, ga_client_id, {})
  end
end
