# frozen_string_literal: true

class HCASubmissionFailureMailer < TransactionalEmailMailer
  # Note: if subject changes, `SubmissionFailureEmailAnalyticsJob#hca_emails` will need to include the new and previous
  # subject lines for at least one job execution (currently daily)
  SUBJECT = "We can't process your health care application"
  GA_CAMPAIGN_NAME = 'hca-failure'
  GA_DOCUMENT_PATH = '/email/health-care/apply/application/introduction'
  GA_LABEL = 'hca--submission-failed'

  TEMPLATE = 'hca_submission_failure'
end
