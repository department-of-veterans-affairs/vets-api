# frozen_string_literal: true

class VeteranReadinessEmploymentMailer < ApplicationMailer
  def build(user, email_addr)
    @submission_date = Time.current.in_time_zone('America/New_York').strftime('%m/%d/%Y')
    template = File.read('app/mailers/views/veteran_readiness_employment.html.erb')

    mail(
      to: email_addr,
      subject: 'VR&E Counseling Request Confirmation',
      body: ERB.new(template).result(binding)
    )
  end
end
