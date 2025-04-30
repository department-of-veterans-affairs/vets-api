# frozen_string_literal: true

FactoryBot.define do
  factory :ccra_referral_list_entry, class: 'Ccra::ReferralListEntry' do
    category_of_care { 'CARDIOLOGY' }
    referral_number { '5682' }
    referral_expiration_date { (Date.current + 60.days).to_s }
    station_id { '528A6' }
    status { 'AP' }
    referral_last_update_date_time { Time.current.iso8601 }

    initialize_with do
      attributes = {
        category_of_care:,
        referral_number:,
        referral_expiration_date:,
        station_id:,
        status:,
        referral_last_update_date_time:
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
        category_of_care:,
        treating_facility:,
        referral_number:,
        referral_expiration_date: expiration_date,
        referral_date:,
        station_id:,
        appointments: has_appointments ? [{ appointment_date: Date.current.to_s }] : [],
        referring_facility_info: {
          facility_name: referring_facility_name,
          phone: referring_facility_phone,
          facility_code: referring_facility_code,
          address: {
            address1: referring_facility_address1,
            city: referring_facility_city,
            state: referring_facility_state,
            zip_code: referring_facility_zip
          }
        },
        treating_facility_info: {
          phone: phone_number
        },
        treating_provider_info: {
          provider_name:,
          provider_npi:,
          telephone: provider_telephone
        }
      }
      Ccra::ReferralDetail.new(attributes)
    end
  end
end
