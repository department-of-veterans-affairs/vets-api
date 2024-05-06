# frozen_string_literal: true

FactoryBot.define do
  factory :vye_verification, class: 'Vye::Verification' do
    association :user_profile, factory: :vye_user_profile
    association :award, factory: :vye_award

    source_ind { Vye::Verification.source_inds.values.sample }
  end
end
