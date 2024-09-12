# frozen_string_literal: true

class Sidekiq::CreateVeteranSubmissionMiddleware
  def call(job)
    va_gov_submission_id = job['jid']
    va_gov_submission_type = job['class']

    CreateVeteranSubmission.new(va_gov_submission_id, va_gov_submission_type).call

    yield
  end
end
