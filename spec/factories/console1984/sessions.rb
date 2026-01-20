# frozen_string_literal: true

FactoryBot.define do
  factory :console1984_session, class: 'Console1984::Session' do
    association :user, factory: :console1984_user
    reason { 'Investigating production issue' }

    trait :with_commands do
      after(:create) do |session|
        create_list(:console1984_command, 3, session: session)
      end
    end

    trait :with_sensitive_access do
      after(:create) do |session|
        sensitive_access = create(:console1984_sensitive_access, session: session)
        create(:console1984_command, session: session, sensitive_access: sensitive_access)
      end
    end
  end
end
