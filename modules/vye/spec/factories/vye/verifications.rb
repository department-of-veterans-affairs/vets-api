# frozen_string_literal: true

FactoryBot.define do
  factory :vye_verification, class: 'Vye::Verification' do
    association :user_profile, factory: :vye_user_profile
    association :award, factory: :vye_award

    transact_date { Time.zone.now }
    source_ind { 'web' }
  end
end
