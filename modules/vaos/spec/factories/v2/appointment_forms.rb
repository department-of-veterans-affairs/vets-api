# frozen_string_literal: true

FactoryBot.define do
  factory :appointment_form_v2, class: 'VAOS::V2::AppointmentForm' do
    transient do
      user { build(:user, :vaos) }
    end

    initialize_with { new(user, attributes) }

    trait :community_cares_base do
      kind { 'cc' }
      location_id { '983' }
      service_type { 'podiatry' } # transforms on the front-end need to change
      comment {}
      practitioners do
        [
          {
            identifier: [
              {
                system: 'http://hl7.org/fhir/sid/us-npi',
                value: '1407938061'
              }
            ],
            address: {
              type: 'postal',
              line: [
                '38143 Martha Ave'
              ],
              city: 'Fremont',
              state: 'CA',
              postal_code: '94536',
              country: 'USA',
              text: 'test'
            }
          }
        ]
      end
      requested_periods do
        [
          {
            'start' => DateTime.new(2021, 0o6, 15, 12, 0o0, 0).iso8601(3),
            'end' => DateTime.new(2021, 0o6, 15, 23, 59, 0).iso8601(3)
          }
        ]
      end
      preferred_times_for_phone_call { ['Morning'] }
      preferred_language { 'English' }
      preferred_location do
        {
          city: 'Helena',
          state: 'MT'
        }
      end
    end

    trait :community_cares_valid_reason_code_text do
      community_cares_base
      status { 'proposed' }
      reason_code do
        { text: 'colon:in:comment' }
      end
    end

    trait :community_cares do
      community_cares_base
      status { 'proposed' }
      contact do
        {
          'telecom' => [
            {
              type: 'phone',
              value: '2125688887'
            },
            {
              type: 'email',
              value: 'judymorisooooooooooooon@gmail.com'
            }
          ]
        }
      end
      reason_code do
        {
          'coding' => [
            {
              code: 'Routine Follow-up'
            }
          ],
          text: 'string'
        }
      end
    end

    trait :community_cares_multiple_request_dates do
      community_cares
      requested_periods do
        [
          {
            start: '2024-08-28T06:00:00Z',
            end: '2024-08-28T17:59:00Z'
          },
          {
            start: '2024-08-28T18:00:00Z',
            end: '2024-08-29T05:59:00Z'
          }
        ]
      end
    end

    trait :community_cares_no_request_dates do
      community_cares
      requested_periods do
        []
      end
    end

    trait :community_cares2 do
      kind { 'cc' }
      status { 'proposed' }
      location_id { '983' }
      service_type { 'podiatry' } # transforms on the front-end need to change
      comment {}
      practitioners do
        [
          {
            identifier: [
              {
                system: 'http://hl7.org/fhir/sid/us-npi',
                value: '1174506877'
              }
            ],
            address: {
              type: 'postal',
              line: [
                '590 MALABAR RD SE STE 5'
              ],
              city: 'PALM BAY',
              state: 'FL',
              postal_code: '32907-3108',
              country: 'USA',
              text: 'test'
            }
          }
        ]
      end
      contact do
        {
          'telecom' => [
            {
              type: 'phone',
              value: '2762740095'
            },
            {
              type: 'email',
              value: 'jacqueline.morgan@id.me'
            }
          ]
        }
      end
      requested_periods do
        [
          {
            'start' => DateTime.new(2023, 0o1, 17, 0o7, 0o0, 0).iso8601(3),
            'end' => DateTime.new(2023, 0o1, 17, 18, 59, 0).iso8601(3)
          }
        ]
      end
      preferred_times_for_phone_call { ['Morning'] }
      preferred_language { 'English' }
      preferred_location do
        {
          city: 'Palm Bay',
          state: 'FL'
        }
      end
      reason_code do
        {
          'coding' => [
            {
              code: 'Routine Follow-up'
            }
          ],
          text: 'string'
        }
      end
    end

    trait :va_base do
      kind { 'clinic' }
      location_id { '983' }
      clinic { '999' } # this is the clinic id for audiology
      slot do
        {
          id: '3230323231313330323034353A323032323131333032313030'
        }
      end
      extension do
        {
          desired_date: DateTime.new(2022, 11, 30)
        }
      end
    end

    trait :va_booked do
      va_base
      status { 'booked' }
      reason_code do
        { 'coding' => [
            code: 'Routine Follow-up'
          ],
          text: 'testing' }
      end
    end

    trait :va_booked_valid_reason_code_text do
      va_base
      status { 'booked' }
      reason_code do
        { text: 'reasonCode:ROUTINEVISIT|comments:colon:in:comment' }
      end
    end

    trait :va_cancelled_valid_reason_code_text do
      va_base
      status { 'cancelled' }
      reason_code do
        { text: 'reasonCode:ROUTINEVISIT|comments:colon:in:comment' }
      end
    end

    trait :va_proposed_base do # this has an error, bring up in SOS
      status { 'proposed' }
      location_id { '983' }
      service_type { 'audiology' }
      comment { 'Follow-up/Routine: testing' }
      requested_periods do
        [
          {
            end: '2022-01-04T11:59:00Z',
            start: '2022-01-04T00:00:00Z'
          }
        ]
      end
    end

    trait :va_proposed_valid_reason_code_text do
      va_proposed_base
      kind { 'clinic' }
      reason_code do
        { text: 'station id: 983|preferred modality: FACE TO FACE|phone number: 6195551234|email: myemail72585885@unattended.com|preferred dates:06/26/2024 AM,06/26/2024 PM|reason code:ROUTINEVISIT|comments:colon:in:comment' } # rubocop:disable Layout/LineLength
      end
    end

    trait :va_proposed_valid_and_invalid_reason_code_text do
      va_proposed_base
      kind { 'clinic' }
      reason_code do
        { text: 'station id: 983|preferred modality: FACE TO FACE|phone number: 6195551234|email: myemail72585885@unattended.com|preferred dates:06/26/2024 AM,06/26/2024 PM|reason code|comments:|test:gwef:fwege' } # rubocop:disable Layout/LineLength
      end
    end

    trait :va_proposed_invalid_reason_code_text do
      va_proposed_base
      reason_code do
        { text: 'invalidkeyvaluepair|invalid:key:value:pair||' }
      end
    end

    trait :va_proposed do # this has an error, bring up in SOS
      va_proposed_base
      reason_code do
        { 'codeing' => [
            code: 'Routine Follow-up'
          ],
          text: 'testing' }
      end
      contact do
        {
          'telecom' => [
            {
              type: 'phone',
              value: '2125688889'
            },
            {
              type: 'email',
              value: 'judymorisooooooooooooon@gmail.com'
            }
          ]
        }
      end
      requested_periods do
        [
          {
            end: '2022-01-04T11:59:00Z',
            start: '2022-01-04T00:00:00Z'
          }
        ]
      end
    end

    trait :va_proposed_clinic do
      va_proposed
      kind { 'clinic' }
    end

    trait :va_proposed_phone do
      va_proposed
      kind { 'phone' }
    end

    trait :with_direct_scheduling_base do
      kind { 'cc' }
      status { 'booked' }
      location_id { '983' }
      practitioner_ids { [{ system: 'HSRM', value: '1234567890' }] }
      preferred_language { 'English' }
      reason { 'Testing' }
      service_type { 'CCPOD' }
    end

    trait :ds_cc_booked_valid_reason_code_text do
      with_direct_scheduling_base

      reason_code do
        { text: 'colon:in:comment' }
      end
    end

    trait :with_direct_scheduling do
      with_direct_scheduling_base

      contact do
        {
          'telecom' => [
            {
              type: 'phone',
              value: '2125688889'
            },
            {
              type: 'email',
              value: 'judymorisooooooooooooon@gmail.com'
            }
          ]
        }
      end

      requested_periods do
        [
          {
            'start' => DateTime.new(2021, 0o6, 15, 12, 0o0, 0).iso8601(3),
            'end' => DateTime.new(2021, 0o6, 15, 23, 59, 0).iso8601(3)
          }
        ]
      end
    end

    trait :with_empty_slot_hash do
      community_cares
      slot { {} }
    end

    trait :telehealth do
      va_proposed_base
      kind { 'telehealth' }

      telehealth do
        {
          vvs_kind: 'CLINIC_BASED'
        }
      end
    end
  end
end
