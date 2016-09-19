# frozen_string_literal: true
require './lib/sm/client_session'

FactoryGirl.define do
  factory :session, class: SM::ClientSession do
    user_id 1234
    token 'o7nsKRFVeijDG8u59/D6JOMrCmXMZO8p'
    expires_at 'Thu, 26 Dec 2015 15:54:21 GMT'

    trait :valid_user do
      user_id ENV['MHV_SM_USER_ID']
      token nil
      expires_at nil
    end

    trait :invalid_user do
      user_id 106_166
      token nil
      expires_at nil
    end

    trait :earlier do
      expires_at 'Thu, 26 Dec 2015 15:54:20 GMT'
    end

    trait :later do
      expires_at 'Thu, 26 Dec 2015 15:54:22 GMT'
    end
  end
end
