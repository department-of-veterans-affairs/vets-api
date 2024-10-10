# frozen_string_literal: true

FactoryBot.define do
  sequence(:uuid, &:to_s)
  sequence(:factory_id) { |n| (n + 1).to_s }

  factory :claims_api_base_factory, class: Hash do
    id { FactoryBot.generate(:uuid) }
    status { %w[pending errored submitted].sample }
    auth_headers { { test: ('a'..'z').to_a.shuffle.join } }
    cid {
      %w[0oa9uf05lgXYk6ZXn297 0oa66qzxiq37neilh297 0oadnb0o063rsPupH297 0oadnb1x4blVaQ5iY297
         0oadnavva9u5F6vRz297 0oagdm49ygCSJTp8X297 0oaqzbqj9wGOCJBG8297 0oao7p92peuKEvQ73297].sample
    }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }
  end

  trait :with_full_headers do
    auth_headers {
      {
        va_eauth_pnid: '796378881',
        va_eauth_pid: '796378881',
        va_eauth_birthdate: '1953-12-05',
        va_eauth_firstName: 'JESSE',
        va_eauth_lastName: 'GRAY'
      }
    }
  end

  trait :with_full_headers_tamara do
    auth_headers {
      {
        va_eauth_pnid: '600043201',
        va_eauth_pid: '600043201',
        va_eauth_birthdate: '1967-06-19',
        va_eauth_firstName: 'Tamara',
        va_eauth_lastName: 'Ellis'
      }
    }
  end

  trait :errored do
    status { 'errored' }
  end

  trait :pending do
    status { 'pending' }
  end

  trait :submitted do
    status { 'submitted' }
  end

  trait :vbms_error_message do
    vbms_error_message { 'A VBMS error has occurred' }
  end
end
