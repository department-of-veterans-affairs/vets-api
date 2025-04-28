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
    referral_date { Date.current.to_s }
    station_id { '528A6' }
    phone_number { '555-123-4567' }
    referring_facility_name { 'Dayton VA Medical Center' }
    referring_facility_phone { '(937) 262-3800' }
    referring_facility_code { '552' }
    referring_facility_address1 { '4100 West Third Street' }
    referring_facility_city { 'DAYTON' }
    referring_facility_state { 'OH' }
    referring_facility_zip { '45428' }
    has_appointments { true }

    initialize_with do
      attributes = {
        'categoryOfCare' => category_of_care,
        'treatingFacility' => treating_facility,
        'referralNumber' => referral_number,
        'referralExpirationDate' => expiration_date,
        'referralDate' => referral_date,
        'stationId' => station_id,
        'appointments' => has_appointments ? [{ 'appointmentDate' => Date.current.to_s }] : [],
        'referringFacilityInfo' => {
          'facilityName' => referring_facility_name,
          'phone' => referring_facility_phone,
          'facilityCode' => referring_facility_code,
          'address' => {
            'address1' => referring_facility_address1,
            'city' => referring_facility_city,
            'state' => referring_facility_state,
            'zipCode' => referring_facility_zip
          }
        },
        'treatingFacilityInfo' => {
          'phone' => phone_number
        },
        'treatingProviderInfo' => {
          'providerName' => provider_name,
          'providerNpi' => provider_npi,
          'telephone' => provider_telephone
        }
      }
      Ccra::ReferralDetail.new(attributes)
    end
  end
end
