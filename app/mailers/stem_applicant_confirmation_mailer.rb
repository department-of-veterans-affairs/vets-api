# frozen_string_literal: true

class StemApplicantConfirmationMailer < TransactionalEmailMailer
  SUBJECT = 'VA Rogers STEM Scholarship, Application Confirmation'
  GA_CAMPAIGN_NAME = 'stem_applicant_confirmation-10203-submission-notification'
  GA_DOCUMENT_PATH = '/email/form'
  GA_LABEL = 'stem-applicant-confirmation-10203-submission-notification'
  TEMPLATE = 'stem_applicant_confirmation'

  STAGING_RECIPIENTS = %w[
    Delli-Gatti_Michael@bah.com
    roth_matthew@bah.com
    shawkey_daniel@bah.com
    sonntag_adam@bah.com
  ].freeze

  def first_and_last_name
    return '' if @applicant.veteranFullName.nil?

    "#{@applicant.veteranFullName.first} #{@applicant.veteranFullName.last}"
  end

  def application_date
    @claim.created_at.strftime('%b %d, %Y')
  end

  def build(claim, ga_client_id)
    @applicant = claim.open_struct_form
    @claim = claim

    opt = {}
    opt[:bcc] = STAGING_RECIPIENTS.clone if FeatureFlipper.staging_email?

    super([@applicant.email], ga_client_id, opt)
  end
end
