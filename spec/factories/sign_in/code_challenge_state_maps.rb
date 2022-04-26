# frozen_string_literal: true

FactoryBot.define do
  factory :code_challenge_state_map, class: 'SignIn::CodeChallengeStateMap' do
    code_challenge { Base64.urlsafe_encode64(SecureRandom.hex) }
    state { SecureRandom.hex }
    client_state { SecureRandom.hex }
  end
end
