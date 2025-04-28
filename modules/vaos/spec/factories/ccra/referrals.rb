# frozen_string_literal: true

FactoryBot.define do
  factory :ccra_referral_list_entry, class: 'Ccra::ReferralListEntry' do
    categoryOfCare { 'CARDIOLOGY' }
    referralNumber { 'VA0000005681' }
    referralDate { Date.current.to_s }
    seocNumberOfDays { '60' }
    status { 'A' }
    stationId { '552' }
    sta6 { '984' }
    lastUpdateDateTime { "#{Date.current} 10:30:00" }
    referralConsultId { '984_646372' }

    initialize_with do
      attributes = {
        'categoryOfCare' => categoryOfCare,
        'referralNumber' => referralNumber,
        'referralDate' => referralDate,
        'seocNumberOfDays' => seocNumberOfDays,
        'status' => status,
        'stationId' => stationId,
        'sta6' => sta6,
        'referralLastUpdateDateTime' => lastUpdateDateTime,
        'referralConsultId' => referralConsultId
      }
      Ccra::ReferralListEntry.new(attributes)
    end
  end

  factory :ccra_referral_detail, class: 'Ccra::ReferralDetail' do
    categoryOfCare { 'CARDIOLOGY' }
    providerName { 'Dr. Smith' }
    providerNpi { '1234567890' }
    providerTelephone { '555-987-6543' }
    treatingFacility { 'VA Medical Center' }
    referralNumber { 'VA0000005681' }
    expirationDate { (Date.current + 30.days).to_s }
    phoneNumber { '555-123-4567' }
    referringFacilityName { 'Dayton VA Medical Center' }
    referringFacilityPhone { '(937) 262-3800' }
    referringFacilityCode { '552' }
    referringFacilityAddress1 { '4100 West Third Street' }
    referringFacilityCity { 'DAYTON' }
    referringFacilityState { 'OH' }
    referringFacilityZip { '45428' }
    referralDate { Date.current.to_s }
    stationId { '552' }

    initialize_with do
      attributes = {
        'categoryOfCare' => categoryOfCare,
        'treatingFacility' => treatingFacility,
        'referralNumber' => referralNumber,
        'referralExpirationDate' => expirationDate,
        'referralDate' => referralDate,
        'stationId' => stationId,
        'appointments' => [{ 'appointmentDate' => Date.current.to_s }],
        'referringFacilityInfo' => {
          'facilityName' => referringFacilityName,
          'phone' => referringFacilityPhone,
          'facilityCode' => referringFacilityCode,
          'address' => {
            'address1' => referringFacilityAddress1,
            'city' => referringFacilityCity,
            'state' => referringFacilityState,
            'zipCode' => referringFacilityZip
          }
        },
        'treatingFacilityInfo' => {
          'phone' => phoneNumber
        },
        'treatingProviderInfo' => {
          'providerName' => providerName,
          'providerNpi' => providerNpi,
          'telephone' => providerTelephone
        }
      }
      Ccra::ReferralDetail.new(attributes)
    end
  end
end
