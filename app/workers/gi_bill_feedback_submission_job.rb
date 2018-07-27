# frozen_string_literal: true

module GIBillFeedbackSubmissionJob
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform(feedback_id, form, user_uuid)
    Sentry::TagRainbows.tag
    @feedback_id = feedback_id
  rescue StandardError
    submission.update_attributes!(state: 'failed')
    raise
  end

  def gi_bill_feedback
    @gi_bill_feedback ||= GIBillFeedback.find(@feedback_id)
  end
end
