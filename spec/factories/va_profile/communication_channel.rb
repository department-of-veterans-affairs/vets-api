# frozen_string_literal: true

FactoryBot.define do
  factory :communication_channel, class: 'VAProfile::Models::CommunicationChannel' do
    id { 1 }
    communication_permission
  end
end
