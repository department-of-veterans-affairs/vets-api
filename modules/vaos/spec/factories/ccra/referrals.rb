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
    provider_npi { '1234567890' }
    provider_telephone { '555-987-6543' }
    treating_facility { 'VA Medical Center' }
    referral_number { 'VA0000005681' }
    expiration_date { (Date.current + 30.days).to_s }
    phone_number { '555-123-4567' }
    referring_facility_name { 'Dayton VA Medical Center' }
    referring_facility_phone { '(937) 262-3800' }
    referring_facility_code { '552' }
    referring_facility_address1 { '4100 West Third Street' }
    referring_facility_city { 'DAYTON' }
    referring_facility_state { 'OH' }
    referring_facility_zip { '45428' }
    has_appointments { 'Y' }

    initialize_with do
      attributes = {
        'Referral' => {
          'CategoryOfCare' => category_of_care,
          'TreatingFacility' => treating_facility,
          'ReferralNumber' => referral_number,
          'ReferralExpirationDate' => expiration_date,
          'APPTYesNo1' => has_appointments,
          'ReferringFacilityInfo' => {
            'FacilityName' => referring_facility_name,
            'Phone' => referring_facility_phone,
            'FacilityCode' => referring_facility_code,
            'Address' => {
              'Address1' => referring_facility_address1,
              'City' => referring_facility_city,
              'State' => referring_facility_state,
              'ZipCode' => referring_facility_zip
            }
          },
          'TreatingFacilityInfo' => {
            'Phone' => phone_number
          },
          'TreatingProviderInfo' => {
            'ProviderName' => provider_name,
            'ProviderNPI' => provider_npi,
            'Telephone' => provider_telephone
          }
        }
      }
      Ccra::ReferralDetail.new(attributes)
    end
  end
end
