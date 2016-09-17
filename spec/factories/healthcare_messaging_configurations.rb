# frozen_string_literal: true
require './lib/va_healthcare_messaging/configuration'

FactoryGirl.define do
  factory :configuration, class: VaHealthcareMessaging::Configuration do
    host ENV['MHV_SM_HOST']
    app_token ENV['MHV_SM_APP_TOKEN']
  end
end
