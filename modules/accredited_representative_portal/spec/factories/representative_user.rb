# frozen_string_literal: true

FactoryBot.define do
  factory :representative_user, class: 'AccreditedRepresentativePortal::RepresentativeUser' do
    transient do
      sign_in_service_name { SignIn::Constants::Auth::IDME }
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

    trait :with_power_of_attorney_holders do
      transient do
        poa_holders_count { 1 }
        poa_holders { [] }
      end

      after(:build) do |user, evaluator|
        list = if evaluator.poa_holders.present?
                 evaluator.poa_holders
               elsif evaluator.poa_holders_count.positive?
                 build_list(
                   :power_of_attorney_holder,
                   evaluator.poa_holders_count
                 )
               end

        user.instance_variable_set(:@power_of_attorney_holders, list)
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
