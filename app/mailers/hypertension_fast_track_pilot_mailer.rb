# frozen_string_literal: true

class HypertensionFastTrackPilotMailer < ApplicationMailer
  def build(submission)
    @submission = submission
    @disability = 'hypertension'
    @rrd_claim_processed = RapidReadyForDecision::Form526BaseJob.rrd_claim_processed?(submission)

    subject =
      if @rrd_claim_processed
        'RRD claim - Processed'
      else
        'RRD claim - Insufficient Data'
      end

    template = File.read('app/mailers/views/hypertension_fast_track_pilot_mailer.erb.html')

    mail(
      to: Settings.rrd.event_tracking.recipients,
      subject: subject,
      body: ERB.new(template).result(binding)
    )
  end
end
