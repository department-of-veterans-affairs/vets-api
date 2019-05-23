# frozen_string_literal: true

class DirectDepositMailer < ApplicationMailer
  SUBJECT = 'Confirmation - Your direct deposit information changed on VA.gov'

  def build(email)
    template = File.read('app/mailers/views/direct_deposit.html.erb')

    mail(
      to: email,
      subject: SUBJECT,
      content_type: 'text/html',
      body: ERB.new(template).result(binding)
    )
  end
end
