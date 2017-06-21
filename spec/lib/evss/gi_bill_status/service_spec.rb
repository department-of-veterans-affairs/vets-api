# frozen_string_literal: true
require 'rails_helper'

describe EVSS::GiBillStatus::Service do
  describe '.find_by_user' do
    let(:user) { build(:loa3_user) }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

    subject { described_class.new(auth_headers) }

    describe '#get_gi_bill_status' do
      context 'with a valid evss response' do
        it 'returns a valid response object' do
          VCR.use_cassette('evss/gi_bill_status/gi_bill_status') do
            response = subject.get_gi_bill_status
            expect(response).to be_ok
            expect(response).to have_deep_attributes(
              'status' => 200,
              'first_name' => 'Dianne',
              'last_name' => 'Scott',
              'name_suffix' => nil,
              'date_of_birth' => '1969-04-06T05:00:00.000+0000',
              'va_file_number' => '796056674',
              'regional_processing_office' => 'Central Office Washington, DC',
              'eligibility_date' => nil,
              'delimiting_date' => nil,
              'percentage_benefit' => nil,
              'original_entitlement' => nil,
              'used_entitlement' => nil,
              'remaining_entitlement' => nil,
              'enrollments' => [
                {
                  'begin_date' => '2009-09-01T04:00:00.000+00:00',
                  'end_date' => '2009-12-01T05:00:00.000+00:00',
                  'facility_code' => '14925438',
                  'facility_name' => 'HARRISBURG AREA COMMUNITY COLLEGE',
                  'participant_id' => '11162086',
                  'training_type' => 'UNDER_GRAD',
                  'term_id' => nil,
                  'hour_type' => nil,
                  'full_time_hours' => 12,
                  'full_time_credit_hour_under_grad' => nil,
                  'vacation_day_count' => 0,
                  'on_campus_hours' => 12.0,
                  'online_hours' => 0.0,
                  'yellow_ribbon_amount' => 1400.0,
                  'status' => 'Approved',
                  'amendments' => []
                }
              ]
            )
          end
        end
      end

      context 'with a Faraday::ClientError' do
        it 'returns a valid response object' do
          VCR.use_cassette('evss/gi_bill_status/gi_bill_status_500') do
            response = subject.get_gi_bill_status
            expect(response).to_not be_ok
            expect(response.response_status).to eq(EVSS::Response::RESPONSE_STATUS[:server_error])
          end
        end
      end
    end
  end
end
