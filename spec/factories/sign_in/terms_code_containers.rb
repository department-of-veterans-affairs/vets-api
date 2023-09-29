# frozen_string_literal: true

FactoryBot.define do
  factory :terms_code_container, class: 'SignIn::TermsCodeContainer' do
    code { SecureRandom.hex }
    user_uuid { SecureRandom.uuid }
  end
end
