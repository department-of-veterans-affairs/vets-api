# frozen_string_literal: true

class SchoolCertifyingOfficialsMailer < ApplicationMailer
  SUBJECT = 'Applicant for VA Rogers STEM Scholarship'

  STAGING_RECIPIENTS = %w[
      Delli-Gatti_Michael@bah.com
      roth_matthew@bah.com
      shawkey_daniel@bah.com
      sonntag_adam@bah.com
  ].freeze

  def build(recipients, applicant, body)
    recipients = recipients + STAGING_RECIPIENTS.clone if FeatureFlipper.staging_email?

    mail(
        {
            to: recipients,
            cc: applicant,
            subject: SUBJECT,
            body: body
      }
    )
  end
end
