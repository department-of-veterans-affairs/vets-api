# frozen_string_literal: true

class FeedbackSubmissionMailer < ApplicationMailer
  RECIPIENTS = %w(
    feedback@va.gov
  ).freeze

  STAGING_RECIPIENTS = %w(
    bill.ryan@adhocteam.us
    leanna@adhocteam.us
    dawn@adhocteam.us
    joshua.quagliaroli@va.gov
    rachael.roueche@adhocteam.us
    nick.sullivan@adhocteam.us
  ).freeze

  def build(feedback, github_link, github_issue_number)
    @feedback = feedback
    @github_link = github_link.presence || 'Warning: No Github link present!'
    @github_issue_number = github_issue_number || -1
    template = File.read('app/mailers/views/feedback_report.erb')

    mail(
      to: recipients,
      subject: subject_line,
      body: ERB.new(template).result(binding)
    )
  end

  private

  def recipients
    FeatureFlipper.staging_email? ? STAGING_RECIPIENTS.clone : RECIPIENTS.clone
  end

  def subject_line
    subject = "#{@github_issue_number}: Vets.gov Feedback Received"
    subject += ' - Response Requested' if @feedback.owner_email.present?
    subject
  end
end
