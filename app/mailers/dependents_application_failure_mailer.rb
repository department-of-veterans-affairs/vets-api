# frozen_string_literal: true

class DependentsApplicationFailureMailer < ApplicationMailer
  def build(user)
    opt = {}

    opt[:to] = [
      user.email,
      'Jason.Wolf@va.gov',
      'Kathleen.Crawford@va.gov',
      'Kevin.Musiorski@va.gov',
      'Amanda.Leaders@va.gov'
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
