# frozen_string_literal: true

FactoryBot.define do
  factory :telephone, class: 'VAProfile::Models::Telephone' do
    area_code { '303' }
    country_code { '1' }
    extension { nil }
    is_international { false }
    phone_number { '5551234' }
    phone_type { 'MOBILE' }
    is_textable { true }
    is_text_permitted { true }
    is_tty { true }
    is_voicemailable { true }
    sequence(:id) { |n| n }
    sequence(:transaction_id, 100) { |n| "d2fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    source_date          { '2018-04-09T11:52:03-06:00' }
    created_at           { '2017-04-09T11:52:03-06:00' }
    updated_at           { '2017-04-09T11:52:03-06:00' }
    vet360_id { '12345' }

    trait :home do
      phone_type { 'HOME' }
      is_textable { false }
      is_text_permitted { false }
    end

    trait :work do
      phone_type { 'WORK' }
      extension { '101' }
      is_textable { false }
      is_text_permitted { false }
    end

    trait :fax do
      phone_type { 'FAX' }
    end

    trait :temporary do
      phone_type { 'TEMPORARY' }
      is_textable { false }
      is_text_permitted { false }
    end

    trait :contact_info_v2 do
      source_date { '2024-08-27T18:51:06.000Z' }
      effective_start_date { '2024-08-27T18:51:06.00Z' }
      is_voicemailable { true }
      is_text_permitted { true }
      is_textable { true }
      is_tty { false }
    end

    trait :contact_info_v2_mobile do
      phone_type { 'MOBILE' }
      is_textable { false }
      is_text_permitted { false }
      source_date { '2024-08-27T18:51:06.012Z' }
      is_tty { false }
    end

    trait :contact_info_v2_international do
      country_code { '355' }
      phone_type { 'HOME' }
      is_textable { false }
      is_text_permitted { false }
      source_date { '2024-08-27T18:51:06.012Z' }
    end
  end
end
