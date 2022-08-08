# frozen_string_literal: true

class RrdMasNotificationMailer < ApplicationMailer
  def build(submission)
    @id = submission.id
    @submitted_claim_id = submission.submitted_claim_id
    @created_at = submission.created_at
    @created_at = submission.created_at
    @disabilities = submission.disabilities

    template = File.read('app/mailers/views/rrd_mas_notification_mailer.html.erb')

    mail(
      to: Settings.rrd.mas_tracking.recipients,
      subject: "MA claim - #{submission.diagnostic_codes.join(', ')}",
      body: ERB.new(template).result(binding)
    )
  end
end
