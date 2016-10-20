class ApplicationMailer < ActionMailer::Base
  default from: "Usva.vets.gov@public.govdelivery.com"
  layout 'mailer'
end
