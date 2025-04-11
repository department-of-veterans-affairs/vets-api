# frozen_string_literal: true

FactoryBot.define do
  factory :ccra_referral_list_entry, class: 'Ccra::ReferralListEntry' do
    category_of_care { 'CARDIOLOGY' }
    referral_number { '5682' }
    start_date { Date.current.to_s }
    seoc_days { '60' }

    initialize_with do
      attributes = {
        'CategoryOfCare' => category_of_care,
        'ID' => referral_number,
        'StartDate' => start_date,
        'SEOCNumberOfDays' => seoc_days
      }
      Ccra::ReferralListEntry.new(attributes)
    end
  end

  factory :ccra_referral_detail, class: 'Ccra::ReferralDetail' do
    category_of_care { 'CARDIOLOGY' }
    provider_name { 'Dr. Smith' }
    location { 'VA Medical Center' }
    referral_number { 'VA0000005681' }
    expiration_date { '2024-05-27' }
    treating_facility_phone { '555-123-4567' }

    initialize_with do
      attributes = {
        'Referral' => {
          'CategoryOfCare' => category_of_care,
          'TreatingProvider' => provider_name,
          'TreatingFacility' => location,
          'ReferralNumber' => referral_number,
          'ReferralExpirationDate' => expiration_date,
          'treatingFacilityPhone' => treating_facility_phone
        }
      }
      Ccra::ReferralDetail.new(attributes)
    end
  end
end
