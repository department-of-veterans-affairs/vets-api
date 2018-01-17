# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "#{FeatureFlipper.staging_email? ? 'Usva.' : ''}vets.gov@public.govdelivery.com"
  layout false
end
