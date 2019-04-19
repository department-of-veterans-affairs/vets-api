# frozen_string_literal: true

FactoryBot.define do
  factory :notification do
    account
    subject { Notification::DASH_HCA }
  end
end
