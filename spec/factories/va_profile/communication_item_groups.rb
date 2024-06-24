# frozen_string_literal: true

require 'va_profile/models/communication_item_group'

FactoryBot.define do
  factory :communication_item_group, class: 'VAProfile::Models::CommunicationItemGroup' do
    transient do
      items_count { 1 }
    end

    after(:build) do |group, evaluator|
      group.communication_items = build_list(:communication_item, evaluator.items_count)
    end

    sequence(:id) { |n| n }
    sequence(:name) { |n| "Communication Item Group #{n}" }
    description { 'Healthcare Appointment Reminders' }
  end
end
