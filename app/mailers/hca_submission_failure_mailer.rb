# frozen_string_literal: true

class HCASubmissionFailureMailer < TransactionalEmailMailer
  SUBJECT = "We can't process your health care application"
  GA_CAMPAIGN_NAME = 'hca-failure'
  GA_DOCUMENT_PATH = '/email/health-care/apply/application/introduction'
  GA_LABEL = 'hca--submission-failed'

  TEMPLATE = 'hca_submission_failure'
end
