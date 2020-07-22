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

  def build(applicant, recipients, ga_client_id)
    @applicant = applicant
    opt = { cc: applicant.email }
    opt[:bcc] = STAGING_RECIPIENTS.clone if FeatureFlipper.staging_email?
    super(recipients, ga_client_id, opt)
  end
end
