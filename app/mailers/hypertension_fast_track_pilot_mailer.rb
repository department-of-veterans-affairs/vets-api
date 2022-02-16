# frozen_string_literal: true

class HypertensionFastTrackPilotMailer < ApplicationMailer
  def build(submission)
    @submission = submission

    subject =
      if submission.form_json.include? 'VAMC_Hypertension_Rapid_Decision_Evidence.pdf'
        'HTN RRD Claim Processed'
      else
        'HTN RRD Claim - Insufficient Data'
      end

    template = File.read('app/mailers/views/hypertension_fast_track_pilot_mailer.erb.html')

    mail(
      to: Settings.rrd.event_tracking.recipients,
      subject: subject,
      body: ERB.new(template).result(binding)
    )
  end
end
