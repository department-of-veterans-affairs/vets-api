# frozen_string_literal: true

class HypertensionFastTrackPilotMailer < ApplicationMailer
  def build(submission)
    @submission = submission
    @disability = submission.form.dig('form526', 'form526', 'disabilities')&.first
    @disability_code = @disability['diagnosticCode'] if @disability
    @rrd_claim_processed = RapidReadyForDecision::Form526BaseJob.rrd_claim_processed?(submission)
    @bp_readings_count = submission.form.dig('rrd_med_stats', 'bp_readings_count') || 'N/A'

    subject =
      if @rrd_claim_processed
        'RRD claim - Processed'
      else
        'RRD claim - Insufficient Data'
      end
    subject += " - #{@disability_code}"

    template = File.read('app/mailers/views/hypertension_fast_track_pilot_mailer.erb.html')

    mail(
      to: Settings.rrd.event_tracking.recipients,
      subject: subject,
      body: ERB.new(template).result(binding)
    )
  end
end
