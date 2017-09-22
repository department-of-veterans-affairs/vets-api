# frozen_string_literal: true
class FeedbackSubmissionMailer < ApplicationMailer
  RECIPIENTS = %w(
    feedback@va.gov
  ).freeze

  def build(feedback, github_link)
    @feedback = feedback
    @github_link = github_link
    template = File.read('app/mailers/views/feedback_report.erb')

    mail(
      to: recipients,
      subject: subject_line,
      body: ERB.new(template).result(binding)
    )
  end

  private

  def recipients
    FeatureFlipper.staging_email? ? 'bill.ryan@adhocteam.us' : RECIPIENTS.clone
  end

  def subject_line
    subject = 'Vets.gov Feedback Received'
    subject += ' - Response Requested' unless @feedback.owner_email.nil?
    subject
  end
end
