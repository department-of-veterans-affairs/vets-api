# frozen_string_literal: true

class DependentsApplicationFailureMailer < ApplicationMailer
  def build(user)
    opt = {}

    opt[:to] = [
      user.email
    ]

    template = File.read('app/mailers/views/dependents_application_failure.erb')

    mail(
      opt.merge(
        subject: t('dependency_claim_failure_mailer.subject'),
        body: ERB.new(template).result(binding)
      )
    )
  end
end
