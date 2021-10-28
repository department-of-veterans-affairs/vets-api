# frozen_string_literal: true

FactoryBot.define do
  factory :preneed_submission, class: 'Preneeds::PreneedSubmission' do
    tracking_number { "#{SecureRandom.base64(14).tr('+/=', '0aZ')[0..-3]}VG" }
    return_description { 'Some EOAS response' }
  end
end
