# frozen_string_literal: true

class DependentsApplicationFailureMailer < ApplicationMailer
  def build(user)
    template = File.read('app/mailers/views/dependents_application_failure.erb')

    mail(
      to: user.email,
      subject: t('dependency_claim_failuer_mailer.subject'),
      body: ERB.new(template).result(binding)
    )
  end
end
