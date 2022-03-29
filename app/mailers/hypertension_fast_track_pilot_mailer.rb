# frozen_string_literal: true

class HypertensionFastTrackPilotMailer < ApplicationMailer
  def build(submission)
    @submission = submission
    @disability = submission.form.dig('form526', 'form526', 'disabilities')&.first
    @disability_code = @disability['diagnosticCode'] if @disability
    @rrd_status = RapidReadyForDecision::Form526BaseJob.rrd_status(submission)
    @bp_readings_count = submission.form.dig('rrd_metadata', 'med_stats', 'bp_readings_count') || 'N/A'

    template = File.read('app/mailers/views/hypertension_fast_track_pilot_mailer.erb.html')

    mail(
      to: Settings.rrd.event_tracking.recipients,
      subject: "RRD claim - #{@rrd_status.to_s.humanize} - #{@disability_code}",
      body: ERB.new(template).result(binding)
    )
  end
end
