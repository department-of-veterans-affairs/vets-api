# frozen_string_literal: true

FactoryBot.define do
  factory :prescription_details do
    prescription_id                 { 1_435_525 }
    refill_status                   { 'active' }
    refill_date                     { 'Thu, 21 Apr 2016 00:00:00 EDT' }
    refill_submit_date              { 'Tue, 26 Apr 2016 00:00:00 EDT' }
    refill_remaining                { 9 }
    facility_name                   { 'ABC1223' }
    ordered_date                    { 'Tue, 29 Mar 2016 00:00:00 EDT' }
    quantity                        { '10' }
    expiration_date                 { 'Thu, 30 Mar 2017 00:00:00 EDT' }
    prescription_number             { '2719324' }
    prescription_name               { 'Drug 1 250MG TAB' }
    dispensed_date                  { 'Thu, 21 Apr 2016 00:00:00 EDT' }
    station_number                  { '23' }
    is_refillable                   { true }
    is_trackable                    { false }
    cmop_division_phone             { nil }
    in_cerner_transition            { false }
    not_refillable_display_message  { 'test' }
    cmop_ndc_number                 { nil }
    user_id                         { 16_955_936 }
    provider_first_name             { 'MOHAMMAD' }
    provider_last_name              { 'ISLAM' }
    remarks                         { nil }
    division_name                   { 'DAYTON' }
    modified_date                   { '2023-08-11T15:56:58.000Z' }
    institution_id                  { nil }
    dial_cmop_division_phone        { '' }
    disp_status                     { 'Active: Refill in Process' }
    ndc                             { '00173_9447_00' }
    reason                          { nil }
    prescription_number_index       { 'RX' }
    prescription_source             { 'RX' }
    disclaimer                      { nil }
    indication_for_use              { nil }
    indication_for_use_flag         { nil }
    category                        { 'Rx Medication' }
    tracking                        { false }
    rx_rf_records {
      [
        [
          'rf_record',
          [
            {
              refill_status: 'suspended',
              refill_submit_date: 'Wed, 11 Jan 2023 00:00:00 EDT',
              refill_date: 'Sat, 15 Jul 2023 00:00:00 EDT',
              refill_remaining: 4,
              facility_name: 'DAYT29',
              is_refillable: false,
              is_trackable: false,
              prescription_id: 22_332_828,
              sig: nil,
              ordered_date: 'Fri, 04 Aug 2023 00:00:00 EDT',
              quantity: nil,
              expiration_date: nil,
              prescription_number: '2720542',
              prescription_name: 'ONDANSETRON 8 MG TAB',
              dispensed_date: 'Thu, 21 Apr 2016 00:00:00 EDT',
              station_number: '989',
              in_cerner_transition: false,
              not_refillable_display_message: nil,
              cmop_division_phone: nil,
              cmop_ndc_number: nil,
              id: 22_332_828,
              user_id: 16_955_936,
              provider_first_name: nil,
              provider_last_name: nil,
              remarks: nil,
              division_name: nil,
              modified_date: nil,
              institution_id: nil,
              dial_cmop_division_phone: '',
              disp_status: 'Suspended',
              ndc: nil,
              reason: nil,
              prescription_number_index: 'RF1',
              prescription_source: 'RF',
              disclaimer: nil,
              indication_for_use: nil,
              indication_for_use_flag: nil,
              category: 'Rx Medication',
              tracking_list: nil,
              rx_rf_records: nil,
              tracking: false
            }
          ]
        ]
      ]
    }
    tracking_list {
      [
        [
          'tracking',
          [
            {
              carrier: 'UPS',
              completeDateTime: '2023-03-28T04:39:11-04:00',
              dateLoaded: '2023-06-21T13:05:19-04:00',
              dialDivisionPhone: '3082719803',
              divisionPhone: '(308)271-9803',
              id: 3974,
              isLocalTracking: false,
              ndc: '00113002239',
              othersInSamePackage: false,
              rxNumber: 2_719_799,
              stationNumber: 994,
              trackingNumber: '772980271979930000002254',
              viewImageDisplayed: true
            },
            {
              carrier: 'FedEx',
              completeDateTime: '2023-05-28T04:39:11-04:00',
              dateLoaded: '2023-04-21T16:55:19-04:00',
              dialDivisionPhone: '4012719804',
              divisionPhone: '(401)271-9804',
              id: 9878,
              isLocalTracking: false,
              ndc: '00113002240',
              othersInSamePackage: false,
              rxNumber: 2_719_780,
              stationNumber: 995,
              trackingNumber: '332980271979930000002300',
              viewImageDisplayed: false
            }
          ]
        ]
      ]
    }
    trait :with_api_name do
      facility_api_name { 'Dayton Medical Center' }
    end
  end
end
