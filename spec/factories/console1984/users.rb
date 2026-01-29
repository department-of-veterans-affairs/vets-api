# frozen_string_literal: true

FactoryBot.define do
  factory :console1984_user, class: 'Console1984::User' do
    sequence(:username) { |n| "console_user_#{n}" }
  end
end
