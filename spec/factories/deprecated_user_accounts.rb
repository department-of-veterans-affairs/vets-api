# frozen_string_literal: true

FactoryBot.define do
  factory :deprecated_user_account, class: 'DeprecatedUserAccount' do
    user_account { create(:user_account) }
    user_verification { create(:user_verification) }
  end
end
