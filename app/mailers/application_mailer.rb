# frozen_string_literal: true
class ApplicationMailer < ActionMailer::Base
  default from: 'Usva.vets.gov@public.govdelivery.com'
  layout false
end
