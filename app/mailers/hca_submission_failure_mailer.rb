# frozen_string_literal: true

class HCASubmissionFailureMailer < ApplicationMailer
  def build(email)
    template = File.read('app/mailers/views/hca_submission_failure.html.erb')

    mail(
      from: 'va-notifications@public.govdelivery.com',
      to: email,
      subject: "We didn't receive your application",
      content_type: 'text/html',
      body: ERB.new(template).result(binding)
    )
  end
end
