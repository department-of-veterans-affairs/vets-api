# frozen_string_literal: true

class HCASubmissionSuccessMailer < ApplicationMailer
  def build(email, received_at, confirmation_number)
    @received_at = received_at
    @confirmation_number = confirmation_number
    template = File.read('app/mailers/views/hca_submission_success.html.erb')

    mail(
      to: email,
      subject: "We've received your application",
      content_type: 'text/html',
      body: ERB.new(template).result(binding)
    )
  end
end
