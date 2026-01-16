# frozen_string_literal: true

shared_context 'BID Awards CurrentAwardsResponse' do
  let(:mock_response_body) do
    {
      'Award' => {
        'AwardEventList' => {
          'awardEvents' => [
            {
              'awardLineList' => {
                'awardLines' => [
                  {
                    'awardLineRecipientList' => {
                      'awardLineRecipients' => [
                        {
                          'awardAmount' => '462.00',
                          'recipientID' => 12_960_359
                        }
                      ]
                    },
                    'awardLineReasonList' => {
                      'awardLineReasons' => [
                        {
                          'awardLineReasonType' => '00',
                          'awardLineReasonTypeDescription' => 'Original Award'
                        }
                      ]
                    },
                    'awardLineType' => 'IP',
                    'awardLineTypeDesc' => 'Improved Pension',
                    'effectiveDate' => '2002-08-01T00:00:00-05:00',
                    'entitlementType' => '7L',
                    'entitlementTypeDesc' => 'Disability Improved Pension - Vietnam Era',
                    'grossAmount' => '462.00',
                    'netAmount' => '462.00'
                  }
                ]
              },
              'awardEventID' => 6183,
              'awardEventType' => 'S',
              'awardEventStatus' => 'Authorized',
              'awardEventTypeDesc' => 'Supplemental'
            }
          ]
        },
        'AwardRecipientList' => {},
        'awardType' => 'CPL',
        'awardTypeDesc' => 'Compensation/Pension Live',
        'beneficiaryID' => 12_960_359,
        'veteranID' => 12_960_359
      }
    }
  end
end
