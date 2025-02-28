# frozen_string_literal: true

FactoryBot.define do
  factory :representative_user, class: 'AccreditedRepresentativePortal::RepresentativeUser' do
    transient do
      sign_in_service_name { SignIn::Constants::Auth::IDME }
      accredited_individual { nil }
    end

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
        auth_broker: SignIn::Constants::Auth::BROKER_CODE,
        client_id: SecureRandom.uuid,
        service_name: sign_in_service_name
      }
    }

    user_account_uuid { create(:user_account).id }
    uuid { SecureRandom.uuid }

    after(:create) do |user, evaluator|
      if evaluator.accredited_individual.present?
        user.update!(
          email: evaluator.accredited_individual.user_account_email,
          icn: evaluator.accredited_individual.user_account_icn
        )
      end
    end

    trait :with_in_progress_form do
      transient do
        in_progress_form_id { Faker::Form.id }
      end

      after(:create) do |user, evaluator|
        create(
          :in_progress_form,
          {
            form_id: evaluator.in_progress_form_id,
            user_account: user.user_account,
            user_uuid: user.uuid,
            metadata: {
              version: 1,
              returnUrl: 'foo.com'
            }
          }
        )
      end
    end
  end
end
