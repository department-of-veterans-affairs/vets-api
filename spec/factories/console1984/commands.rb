# frozen_string_literal: true

FactoryBot.define do
  factory :console1984_command, class: 'Console1984::Command' do
    association :session, factory: :console1984_session
    statements { 'User.count' }

    trait :sensitive do
      after(:build) do |command|
        command.sensitive_access = build(:console1984_sensitive_access, session: command.session)
      end
    end
  end
end
