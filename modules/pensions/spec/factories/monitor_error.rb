# frozen_string_literal: true

FactoryBot.define do
  factory :monitor_error, class: 'OpenStruct' do
    message { 'MONITOR TEST ERROR' }
  end
end
