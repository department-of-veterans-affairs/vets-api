# frozen_string_literal: true

FactoryBot.define do
  factory :representative_user, class: 'AccreditedRepresentativePortal::RepresentativeUser' do
    authn_context { LOA::IDME_LOA3_VETS }
    email { Faker::Internet.email }
    fingerprint { Faker::Internet.ip_v4_address }
    first_name { Faker::Name.first_name }
    icn { '123498767V234859' }
    idme_uuid { SecureRandom.uuid }
    last_name { Faker::Name.last_name }
    last_signed_in { Time.zone.now }
    loa { { current: LOA::THREE, highest: LOA::THREE } }
    logingov_uuid { SecureRandom.uuid }
    sign_in {
      {
        service_name: SignIn::Constants::Auth::IDME, client_id: SecureRandom.uuid,
        auth_broker: SignIn::Constants::Auth::BROKER_CODE
      }
    }
    uuid { SecureRandom.uuid }
  end
end
