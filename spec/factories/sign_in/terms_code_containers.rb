# frozen_string_literal: true

FactoryBot.define do
  factory :terms_code_container, class: 'SignIn::TermsCodeContainer' do
    code { SecureRandom.hex }
    user_account_uuid { create(:user_account).id }
  end
end
