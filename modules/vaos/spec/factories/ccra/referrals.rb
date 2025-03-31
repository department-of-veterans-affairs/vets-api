# frozen_string_literal: true

FactoryBot.define do
  factory :ccra_referral_list_entry, class: 'Ccra::ReferralListEntry' do
    type_of_care { 'CARDIOLOGY' }
    referral_id { '5682' }
    start_date { '2024-03-28' }
    seoc_days { '60' }

    initialize_with do
      attributes = {
        'CategoryOfCare' => type_of_care,
        'ID' => referral_id,
        'StartDate' => start_date,
        'SEOCNumberOfDays' => seoc_days
      }
      Ccra::ReferralListEntry.new(attributes)
    end
  end

  factory :ccra_referral_detail, class: 'Ccra::ReferralDetail' do
    type_of_care { 'CARDIOLOGY' }
    provider_name { 'Dr. Smith' }
    location { 'VA Medical Center' }
    referral_number { 'VA0000005681' }
    expiration_date { '2024-05-27' }
    phone_number { '555-123-4567' }

    initialize_with do
      attributes = {
        'Referral' => {
          'CategoryOfCare' => type_of_care,
          'TreatingProvider' => provider_name,
          'TreatingFacility' => location,
          'ReferralNumber' => referral_number,
          'ReferralExpirationDate' => expiration_date,
          'ProviderPhone' => phone_number
        }
      }
      Ccra::ReferralDetail.new(attributes)
    end
  end
end
