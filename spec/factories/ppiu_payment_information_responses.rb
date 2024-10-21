# frozen_string_literal: true

FactoryBot.define do
  factory :ppiu_payment_information_response, class: 'EVSS::PPIU::PaymentInformationResponse' do
    initialize_with {
      new(200, OpenStruct.new(body: { 'responses' => build_list(:payment_information, 1).map(&:attributes) }))
    }
  end

  factory :payment_information, class: 'EVSS::PPIU::PaymentInformation' do
    control_information { build(:ppiu_control_information) }
    payment_account { build(:ppiu_payment_account) }
    payment_address { build(:ppiu_payment_address) }
    payment_type { 'CNP' }

    initialize_with { new(attributes) }
  end

  factory :ppiu_control_information, class: 'EVSS::PPIU::ControlInformation' do
    can_update_address { true }
    corp_avail_indicator { true }
    corp_rec_found_indicator { true }
    has_no_bdn_payments_indicator { true }
    identity_indicator { true }
    index_indicator { true }
    is_competent_indicator { true }
    no_fiduciary_assigned_indicator { true }
    not_deceased_indicator { true }

    initialize_with { new(attributes) }
  end

  factory :ppiu_payment_address, class: 'EVSS::PPIU::PaymentAddress' do
    address_effective_date { '2018-06-07T22:47:21.000Z' }
    address_one { 'string' }
    address_two { nil }
    address_three { nil }
    city { nil }
    country_name { nil }
    military_post_office_type_code { nil }
    military_state_code { nil }
    state_code { nil }
    type { 'Domestic' }
    zip_code { nil }
    zip_suffix { nil }

    initialize_with { new(attributes) }
  end
end
