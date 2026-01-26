# frozen_string_literal: true

shared_context 'BID Awards CurrentAwardsResponse' do
  let(:mock_response_body) do
    {
      'award' => {
        'award_event_list' => {
          'award_events' => [
            {
              'award_line_list' => {
                'award_lines' => [
                  {
                    'award_line_recipient_list' => {
                      'award_line_recipients' => [
                        {
                          'award_amount' => '462.00',
                          'recipient_id' => 12_960_359
                        }
                      ]
                    },
                    'award_line_reason_list' => {
                      'award_line_reasons' => [
                        {
                          'award_line_reason_type' => '00',
                          'award_line_reason_type_description' => 'Original Award'
                        }
                      ]
                    },
                    'award_line_type' => 'IP',
                    'award_line_type_desc' => 'Improved Pension',
                    'effective_date' => '2002-08-01T00:00:00-05:00',
                    'entitlement_type' => '7L',
                    'entitlement_type_desc' => 'Disability Improved Pension - Vietnam Era',
                    'gross_amount' => '462.00',
                    'net_amount' => '462.00'
                  }
                ]
              },
              'award_event_id' => 6183,
              'award_event_type' => 'S',
              'award_event_status' => 'Authorized',
              'award_event_type_desc' => 'Supplemental'
            }
          ]
        },
        'award_recipient_list' => {},
        'award_type' => 'CPL',
        'award_type_desc' => 'Compensation/Pension Live',
        'beneficiary_id' => 12_960_359,
        'veteran_id' => 12_960_359
      }
    }
  end
end
