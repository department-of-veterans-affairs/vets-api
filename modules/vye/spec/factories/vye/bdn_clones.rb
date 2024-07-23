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
end
