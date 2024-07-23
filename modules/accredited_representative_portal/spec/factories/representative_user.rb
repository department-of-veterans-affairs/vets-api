# frozen_string_literal: true

FactoryBot.define do
  factory :representative_user, class: 'AccreditedRepresentativePortal::RepresentativeUser' do
    uuid { SecureRandom.uuid }
    email { Faker::Internet.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    icn { '123498767V234859' }
    idme_uuid { SecureRandom.uuid }
    logingov_uuid { SecureRandom.uuid }
    fingerprint { Faker::Internet.ip_v4_address }
    last_signed_in { Time.zone.now }
    authn_context { LOA::IDME_LOA3_VETS }
    loa { { current: LOA::THREE, highest: LOA::THREE } }
    sign_in {
      { service_name: SignIn::Constants::Auth::IDME, client_id: SecureRandom.uuid,
        auth_broker: SignIn::Constants::Auth::BROKER_CODE }
    }
  end
end
