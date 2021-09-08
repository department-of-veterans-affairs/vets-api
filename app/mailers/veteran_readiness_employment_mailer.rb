# frozen_string_literal: true

class VeteranReadinessEmploymentMailer < ApplicationMailer
  def build(user, email_addr, routed_to_cmp)
    email_addr = 'kcrawford@governmentcio.com' if FeatureFlipper.staging_email?

    @routed_to_cmp = routed_to_cmp
    @user = user
    @submission_date = Time.current.in_time_zone('America/New_York').strftime('%m/%d/%Y')
    @pid_text = pid_text

    template = File.read('app/mailers/views/veteran_readiness_employment.html.erb')

    mail(
      to: email_addr,
      subject: 'VR&E Counseling Request Confirmation',
      body: ERB.new(template).result(binding)
    )
  end

  private

  def pid_text
    text = @user.participant_id.to_s
    if @routed_to_cmp
      text + ' (routed to CMP)'
    else
      text
    end
  end
end
