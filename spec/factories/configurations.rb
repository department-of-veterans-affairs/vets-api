# frozen_string_literal: true

require './lib/sm/configuration'

FactoryBot.define do
  factory :configuration, class: 'SM::Configuration' do
    host { Settings.mhv.sm.host }
    app_token { Settings.mhv.sm.app_token }
  end
end
