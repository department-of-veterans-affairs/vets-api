# frozen_string_literal: true

require 'feature_flipper'

class ApplicationMailer < ActionMailer::Base
  default from: "#{FeatureFlipper.staging_email? ? 'stage.' : ''}va-notifications@public.govdelivery.com"
  layout false
end
