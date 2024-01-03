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
    quantity                        { 10 }
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
          "rf_record",
          [
            {
              "refillStatus": "suspended",
              "refillSubmitDate": "Wed, 11 Jan 2023 00:00:00 EDT",
              "refillDate": "Sat, 15 Jul 2023 00:00:00 EDT",
              "refillRemaining": 4,
              "facilityName": "DAYT29",
              "isRefillable": false,
              "isTrackable": false,
              "prescriptionId": 22332828,
              "sig": nil,
              "orderedDate": "Fri, 04 Aug 2023 00:00:00 EDT",
              "quantity": nil,
              "expirationDate": nil,
              "prescriptionNumber": "2720542",
              "prescriptionName": "ONDANSETRON 8 MG TAB",
              "dispensedDate": nil,
              "stationNumber": "989",
              "inCernerTransition": false,
              "notRefillableDisplayMessage": nil,
              "cmopDivisionPhone": nil,
              "cmopNdcNumber": nil,
              "id": 22332828,
              "userId": 16955936,
              "providerFirstName": nil,
              "providerLastName": nil,
              "remarks": nil,
              "divisionName": nil,
              "modifiedDate": nil,
              "institutionId": nil,
              "dialCmopDivisionPhone": "",
              "dispStatus": "Suspended",
              "ndc": nil,
              "reason": nil,
              "prescriptionNumberIndex": "RF1",
              "prescriptionSource": "RF",
              "disclaimer": nil,
              "indicationForUse": nil,
              "indicationForUseFlag": nil,
              "category": "Rx Medication",
              "trackingList": nil,
              "rxRfRecords": nil,
              "tracking": false
            }
          ]
        ]
      ]
    }
  end
end
