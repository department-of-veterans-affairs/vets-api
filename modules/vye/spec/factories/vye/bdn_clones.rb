# frozen_string_literal: true

FactoryBot.define do
  factory :vye_bdn_clone_base, class: 'Vye::BdnClone' do
    is_active { nil }
    transact_date { Time.zone.today }
    export_ready { nil }
  end

  factory :vye_bdn_clone, class: 'Vye::BdnClone' do
    is_active { nil }
    transact_date { Time.zone.today }
    export_ready { nil }

    after(:create) do |bdn_clone|
      create_list(:vye_user_info, 3, bdn_clone:)
    end
  end

  factory :vye_bdn_clone_with_user_info_children, class: 'Vye::BdnClone' do
    transient do
      created_at_override { nil }
      updated_at_override { nil }
    end

    created_at { created_at_override || Time.current }
    updated_at { updated_at_override || Time.current }

    is_active { nil }
    transact_date { Time.zone.today }
    export_ready { nil }

    after(:create) do |bdn_clone, evaluator|
      created_at = evaluator.created_at_override || Time.current
      updated_at = evaluator.updated_at_override || Time.current

      create(:vye_user_info, :with_address_changes, :with_verified_awards, :with_direct_deposit_changes, bdn_clone:)
      bdn_clone.user_infos.each do |u|
        u.update!(created_at:, updated_at:)
        u.address_changes.update!(created_at:, updated_at:)
        u.direct_deposit_changes.update!(created_at:, updated_at:)
        u.awards.update!(created_at:, updated_at:)
        u.verifications.update!(created_at:, updated_at:)
      end
    end

    trait :active do
      is_active { true }
    end
  end
end
