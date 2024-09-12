# frozen_string_literal: true

class Sidekiq::CreateVeteranSubmissionMiddleware
  def call(_job_class_or_string, job, _queue, _redis_pool)
    va_gov_submission_id = job['jid']
    va_gov_submission_type = job['class']

    CreateVeteranSubmission.new(va_gov_submission_id, va_gov_submission_type).call

    yield
  end
end
