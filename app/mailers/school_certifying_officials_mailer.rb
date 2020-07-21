# frozen_string_literal: true

class SchoolCertifyingOfficialsMailer < ApplicationMailer
  SUBJECT = 'Applicant for VA Rogers STEM Scholarship'

  STAGING_RECIPIENTS = %w[
      Delli-Gatti_Michael@bah.com
      roth_matthew@bah.com
      shawkey_daniel@bah.com
      sonntag_adam@bah.com
  ].freeze

  def build(recipients = [], application = {})
    recipients = recipients + STAGING_RECIPIENTS.clone if FeatureFlipper.staging_email?

    mail(
        {
            to: recipients,
            cc: application["email"],
            subject: SUBJECT,
            body: "TEst ajsflkajs;ldfj test tests alfja;l"
      }
    )
  end
end
