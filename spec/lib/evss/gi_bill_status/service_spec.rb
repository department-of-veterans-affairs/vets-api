# frozen_string_literal: true

require 'rails_helper'

describe EVSS::GiBillStatus::Service do
  describe '.find_by_user' do
    let(:user) { build(:user, :loa3) }
    subject { described_class.new(user) }

    describe '#get_gi_bill_status' do
      context 'with a valid evss response' do
        it 'returns a valid response object' do
          VCR.use_cassette('evss/gi_bill_status/gi_bill_status') do
            response = subject.get_gi_bill_status
            expect(response).to be_ok
            expect(response).to have_deep_attributes(
              'status' => 200,
              'first_name' => 'Srikanth',
              'last_name' => 'Vanapalli',
              'name_suffix' => nil,
              'date_of_birth' => '1955-11-12T06:00:00.000+0000',
              'va_file_number' => '123456789',
              'regional_processing_office' => 'Central Office Washington, DC',
              'eligibility_date' => '2004-10-01T04:00:00.000+0000',
              'delimiting_date' => '2015-10-01T04:00:00.000+0000',
              'percentage_benefit' => 100,
              'original_entitlement' => { 'months' => 0, 'days' => 12 },
              'used_entitlement' => { 'months' => 0, 'days' => 10 },
              'remaining_entitlement' => { 'months' => 0, 'days' => 12 },
              'veteran_is_eligible' => true,
              'active_duty' => false,
              'enrollments' => [{
                'begin_date' => '2012-11-01T04:00:00.000+00:00',
                'end_date' => '2012-12-01T05:00:00.000+00:00',
                'facility_code' => '11902614',
                'facility_name' => 'Purdue University',
                'participant_id' => '11170323',
                'training_type' => 'UNDER_GRAD',
                'term_id' => nil,
                'hour_type' => nil,
                'full_time_hours' => 12,
                'full_time_credit_hour_under_grad' => nil,
                'vacation_day_count' => 0,
                'on_campus_hours' => 12.0,
                'online_hours' => 0.0,
                'yellow_ribbon_amount' => 0.0,
                'status' => 'Approved',
                'amendments' => []
              }]
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

      # The EVSS GI Bill service is not capable of returning a status code of 403...
      # but none of the other responses that inherit from EVSS::Response cover
      # this scenario.
      context 'when service returns a 403' do
        it 'contains 403 in meta' do
          VCR.use_cassette('evss/gi_bill_status/gi_bill_status_403') do
            response = subject.get_gi_bill_status
            expect(response).to_not be_ok
            expect(response.response_status).to eq(EVSS::Response::RESPONSE_STATUS[:not_authorized])
          end
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'should raise an exception' do
          expect { subject.get_gi_bill_status }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end
    end
  end
end
