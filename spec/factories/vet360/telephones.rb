# frozen_string_literal: true

FactoryBot.define do
  factory :telephone, class: 'Vet360::Models::Telephone' do
    area_code '303'
    country_code '1'
    extension nil
    is_international false
    phone_number '5551234'
    phone_type 'MOBILE'
    is_textable true
    is_tty true
    is_voicemailable true
    sequence(:id) { |n| n }
    sequence(:transaction_id, 100) { |n| "d2fab2b5-6af0-45e1-a9e2-394347af9#{n}" }
    source_date          '2018-04-09T11:52:03-06:00'
    created_at           '2017-04-09T11:52:03-06:00'
    updated_at           '2017-04-09T11:52:03-06:00'
    vet360_id '12345'

    trait :home do
      phone_type 'HOME'
    end

    trait :work do
      phone_type 'WORK'
      extension '101'
    end

    trait :fax do
      phone_type 'FAX'
    end

    trait :temporary do
      phone_type 'TEMPORARY'
    end
  end
end
