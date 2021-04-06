# frozen_string_literal: true

FactoryBot.define do
  factory :communication_item, class: 'VAProfile::Models::CommunicationItem' do
    id { 2 }

    after(:build) do |communication_item|
      communication_item.communication_channels = [build(:communication_channel)]
    end
  end
end
