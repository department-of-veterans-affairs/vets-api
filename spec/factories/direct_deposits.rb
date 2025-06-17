# frozen_string_literal: true

FactoryBot.define do
  factory :direct_deposit, class: Hash do
    veteran_status { 'VETERAN' }
    control_information

    trait :with_payment_account do
      payment_account
    end
    initialize_with { attributes }
  end

  factory :control_information, class: Hash do
    can_update_direct_deposit { true }
    has_cp_claim { true }
    has_cp_award { true }
    is_corp_available { true }
    is_corp_rec_found { true }
    has_no_bdn_payments { true }
    has_index { true }
    is_competent { true }
    has_mailing_address { true }
    has_no_fiduciary_assigned { true }
    is_not_deceased { true }
    has_payment_address { true }
    is_edu_claim_available { true }
    has_identity { true }

    initialize_with { attributes }
  end

  factory :payment_account, class: Hash do
    name { 'WELLS FARGO BANK' }
    account_type { 'Checking' }
    account_number { '1234567890' }
    routing_number { '031000503' }

    initialize_with { attributes }
  end
end
