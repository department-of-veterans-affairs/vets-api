# frozen_string_literal: true
FactoryBot.define do
  factory :tracking do
    tracking_number       '01234567890'
    prescription_id       2_719_324
    prescription_number   '2719324'
    prescription_name     'Drug 1 250MG TAB'
    facility_name         'ABC123'
    rx_info_phone_number  '(333)772-1111'
    ndc_number            '12345678910'
    shipped_date          Time.parse('Thu, 12 Oct 2016 00:00:00 EDT').in_time_zone
    delivery_service      'UPS'

    trait :oldest do
      shipped_date Time.parse('Thu, 12 Oct 2016 00:00:00 EDT').in_time_zone - 1.year
    end
  end
end
