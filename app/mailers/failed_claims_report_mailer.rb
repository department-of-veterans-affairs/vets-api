# frozen_string_literal: true
class FailedClaimsReportMailer < ApplicationMailer
  RECIPIENTS = %w(
    lihan@adhocteam.us
    mark@adhocteam.us
  ).freeze

  def build(failed_uploads)
    opt = {}
    opt[:to] =
      if FeatureFlipper.staging_email?
        'lihan@adhocteam.us'
      else
        RECIPIENTS.clone
      end

    mail(
      opt.merge(
        subject: 'EVSS claims failed to upload',
        body: failed_uploads.map do |failed_upload|
          ERB::Util.html_escape(failed_upload)
        end.join('<br>')
      )
    )
  end
end
