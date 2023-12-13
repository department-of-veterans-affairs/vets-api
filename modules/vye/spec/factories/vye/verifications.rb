# frozen_string_literal: true

FactoryBot.define do
  factory :vye_verification, class: 'Vye::Verification' do
    change_flag { 'example_change_flag' }
    rpo_code { 1 }
    rpo_flag { true }
    act_begin { DateTime.now }
    act_end { DateTime.now }
    source_ind { 'example_source_ind' }
  end

  trait :ivr do
    ivr_key { Settings.vye.ivr_key }
    ssn { '123456789' }
  end
end
