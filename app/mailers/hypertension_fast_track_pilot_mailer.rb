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
      to: 'emily.theis@va.gov, zachary.goldfine@va.gov, Julia.Allen1@va.gov, paul.shute@va.gov',
      subject: subject,
      body: ERB.new(template).result(binding)
    )
  end
end
