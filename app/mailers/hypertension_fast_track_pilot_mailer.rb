# frozen_string_literal: true

class HypertensionFastTrackPilotMailer < ApplicationMailer
  NOTIFICATION_EMAIL_ADDRESSES = [
    'emily.theis@va.gov',
    'zachary.goldfine@va.gov',
    'Julia.Allen1@va.gov',
    'paul.shute@va.gov',
    'amy.lai2@va.gov',
    'diana.griffin@va.gov',
    'Dung.Lam1@va.gov'
  ].freeze

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
      to: NOTIFICATION_EMAIL_ADDRESSES.join(', '),
      subject: subject,
      body: ERB.new(template).result(binding)
    )
  end
end
