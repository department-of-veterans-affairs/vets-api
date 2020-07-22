# frozen_string_literal: true

class SchoolCertifyingOfficialsMailer < TransactionalEmailMailer
  SUBJECT = 'Applicant for VA Rogers STEM Scholarship'
  TEMPLATE = 'school_certifying_officials'

  STAGING_RECIPIENTS = %w[
      Delli-Gatti_Michael@bah.com
      roth_matthew@bah.com
      shawkey_daniel@bah.com
      sonntag_adam@bah.com
  ].freeze

  def build(recipients, google_analytics_client_id, cc)
    recipients = recipients + STAGING_RECIPIENTS.clone if FeatureFlipper.staging_email?

    super(recipients, google_analytics_client_id, cc)
  end
end
