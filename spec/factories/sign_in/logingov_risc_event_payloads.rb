# frozen_string_literal: true

DEFAULT_ISSUER = 'https://idp.int.identitysandbox.gov'
IDENTIFIER_TYPES = %w[iss-sub email].freeze
EVENT_TYPE_URIS     = {
  account_disabled: :'https://schemas.openid.net/secevent/risc/event-type/account-disabled',
  account_enabled: :'https://schemas.openid.net/secevent/risc/event-type/account-enabled',
  mfa_limit_account_locked: :'https://schemas.login.gov/secevent/risc/event-type/mfa-limit-account-locked',
  account_purged: :'https://schemas.openid.net/secevent/risc/event-type/account-purged',
  identifier_changed: :'https://schemas.openid.net/secevent/risc/event-type/identifier-changed',
  identifier_recycled: :'https://schemas.openid.net/secevent/risc/event-type/identifier-recycled',
  password_reset: :'https://schemas.login.gov/secevent/risc/event-type/password-reset',
  recovery_activated: :'https://schemas.openid.net/secevent/risc/event-type/recovery-activated',
  recovery_information_changed: :'https://schemas.openid.net/secevent/risc/event-type/recovery-information-changed',
  reproof_completed: :'https://schemas.login.gov/secevent/risc/event-type/reproof-completed'
}.freeze

FactoryBot.define do
  sequence(:risc_uuid)  { Faker::Internet.uuid }
  sequence(:risc_email) { Faker::Internet.email }

  factory :logingov_risc_event_payload, class: Hash do
    skip_create

    transient do
      event_name        { EVENT_TYPE_URIS.keys.first }
      event_type        { EVENT_TYPE_URIS.fetch(event_name) }
      subject_type      { IDENTIFIER_TYPES.sample }
      email             { generate(:risc_email) }
      logingov_uuid { generate(:risc_uuid) }
      event_occurred_at { nil }
      reason            { nil }
    end

    initialize_with do
      {
        iss: DEFAULT_ISSUER,
        jti: generate(:risc_uuid),
        iat: Time.current.to_i,
        aud: 'https://va.gov',
        events: {
          event_type => {
            subject: {
              subject_type:,
              iss: DEFAULT_ISSUER,
              email:,
              sub: logingov_uuid
            },
            reason:,
            event_occurred_at:
          }
        }
      }
    end

    EVENT_TYPE_URIS.each_key do |ename|
      trait ename do
        transient { event_name { ename } }
      end
    end

    trait :encoded do
      transient do
        private_key_path { Rails.root.join('spec', 'fixtures', 'sign_in', 'oauth_test.key') }
        private_key      { OpenSSL::PKey::RSA.new(File.read(private_key_path)) }
        algorithm        { 'RS256' }
        kid              { 'some-kid' }
        header           { { typ: 'secevent+jwt', alg: algorithm, kid: } }
      end

      initialize_with do
        payload = FactoryBot.build(
          :logingov_risc_event_payload,
          event_name:,
          subject_type:,
          email:,
          logingov_uuid:,
          event_occurred_at:,
          reason:
        )

        JWT.encode(payload, private_key, algorithm, header)
      end
    end
  end
end

FactoryBot.define do
  factory :logingov_risc_event_jwks, class: Hash do
    skip_create

    transient do
      private_key_path { Rails.root.join('spec', 'fixtures', 'sign_in', 'oauth_test.key') }
      private_key      { OpenSSL::PKey::RSA.new(File.read(private_key_path)) }
      algorithm        { 'RS256' }
      kid              { 'some-kid' }
    end

    initialize_with do
      {
        keys: [
          JWT::JWK.new(private_key, { alg: algorithm, use: 'sig', kid: }).export
        ]
      }
    end
  end
end
