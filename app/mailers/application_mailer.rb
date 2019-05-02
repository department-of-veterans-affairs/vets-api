# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "#{FeatureFlipper.staging_email? ? 'stage.' : ''}va-notifications@public.govdelivery.com"
  layout false
end
