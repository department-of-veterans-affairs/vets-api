class FailedClaimsReportMailer < ApplicationMailer
  RECIPIENTS = %w(
    lihan@adhocteam.us
    mark@adhocteam.us
  )

  def build(failed_uploads)
    opt = {}
    if FeatureFlipper.staging_email?
      opt[:to] = 'lihan@adhocteam.us'
    else
      opt[:to] = RECIPIENTS.clone
    end

    mail(
      opt.merge(
        subject: "EVSS claims failed to upload",
        body: failed_uploads.map do |failed_upload|
          ERB::Util.html_escape(failed_upload)
        end.join('<br>')
      )
    )
  end
end
