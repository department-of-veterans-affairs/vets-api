# frozen_string_literal: true

module GIBillFeedbackSubmissionJob
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform(feedback_id, form)
    Sentry::TagRainbows.tag
    @feedback_id = feedback_id
    gi_bill_feedback.response = Gibft::Service.new.submit(form, User.find(user_uuid)).to_json
    gi_bill_feedback.state = 'success'
    gi_bill_feedback.save!
  rescue StandardError
    gi_bill_feedback.state = 'failed'
    gi_bill_feedback.save!
    raise
  end

  def gi_bill_feedback
    @gi_bill_feedback ||= GIBillFeedback.find(@feedback_id)
  end
end
