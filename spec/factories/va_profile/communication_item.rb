# frozen_string_literal: true

FactoryBot.define do
  factory :communication_item, class: 'VAProfile::Models::CommunicationItem' do
    id { 2 }
    communication_channel
  end
end
