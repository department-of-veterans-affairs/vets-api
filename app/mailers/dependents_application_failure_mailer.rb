# frozen_string_literal: true

class DependentsApplicationFailureMailer < TransactionalEmailMailer
  def build(user_hash)
    @user_hash = user_hash
    template = File.read('app/mailers/views/dependents_application_failure.erb')

    mail(
      to: @user_hash['email'],
      subject: "We can't process your dependents application",
      body: ERB.new(template).result(binding)
    )
  end
end
