# frozen_string_literal: true
require './lib/sm/configuration'

FactoryGirl.define do
  factory :configuration, class: SM::Configuration do
    host ENV['MHV_SM_HOST']
    app_token ENV['MHV_SM_APP_TOKEN']
  end
end
