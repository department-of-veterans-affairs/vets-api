# frozen_string_literal: true

FactoryBot.define do
  factory :ivc_champva_form do
    email { Faker::Internet.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    form_number { '10-10D' }
    file_name { Faker::File.file_name }
    form_uuid { SecureRandom.uuid }
    s3_status { '[200]' }
    pega_status { %w[pending processing completed].sample }
    case_id { 'ABC-1234' }
    email_sent { false }
  end
end
