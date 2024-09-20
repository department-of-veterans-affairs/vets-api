# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::AppointmentsClient do
  let(:user) { build(:user) }

  before do
    @stubs = Faraday::Adapter::Test::Stubs.new

    conn = Faraday.new do |c|
      c.adapter(:test, @stubs)
      c.response :json
      c.request :json
    end

    allow_any_instance_of(TravelPay::AppointmentsClient).to receive(:connection).and_return(conn)
  end

  context 'prod settings' do
    it 'returns both subscription keys in headers' do
      headers =
        {
          'Content-Type' => 'application/json',
          'Ocp-Apim-Subscription-Key-E' => 'e_key',
          'Ocp-Apim-Subscription-Key-S' => 's_key'
        }

      with_settings(Settings, vsp_environment: 'production') do
        with_settings(Settings.travel_pay,
                      { subscription_key_e: 'e_key', subscription_key_s: 's_key' }) do
          expect(subject.send(:claim_headers)).to eq(headers)
        end
      end
    end
  end

  context '/appointments' do
    before do
      allow_any_instance_of(TravelPay::TokenService)
        .to receive(:get_tokens)
        .and_return('veis_token', 'btsss_token')
    end

    it 'returns a response only with appointments with no claims' do
      @stubs.get('/api/v1.1/appointments?excludeWithClaims=true') do
        [
          200,
          {},
          {
            'data' => [
              {
                'id' => 'uuid1',
                'appointmentSource' => 'API',
                'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
                'appointmentName' => 'string',
                'appointmentType' => 'EnvironmentalHealth',
                'facilityName' => 'Cheyenne VA Medical Center',
                'serviceConnectedDisability' => 30,
                'currentStatus' => 'string',
                'appointmentStatus' => 'Completed',
                'externalAppointmentId' => '12345678-0000-0000-0000-000000000001',
                'associatedClaimId' => nil,
                'associatedClaimNumber' => nil,
                'isCompleted' => true
              },
              {
                'id' => 'uuid2',
                'appointmentSource' => 'API',
                'appointmentDateTime' => '2024-03-01T16:45:34.465Z',
                'appointmentName' => 'string',
                'appointmentType' => 'EnvironmentalHealth',
                'facilityName' => 'Cheyenne VA Medical Center',
                'serviceConnectedDisability' => 30,
                'currentStatus' => 'string',
                'appointmentStatus' => 'Completed',
                'externalAppointmentId' => '12345678-0000-0000-0000-000000000002',
                'associatedClaimId' => nil,
                'associatedClaimNumber' => nil,
                'isCompleted' => true
              },
              {
                'id' => 'uuid3',
                'appointmentSource' => 'API',
                'appointmentDateTime' => '2024-02-01T16:45:34.465Z',
                'appointmentName' => 'string',
                'appointmentType' => 'EnvironmentalHealth',
                'facilityName' => 'Cheyenne VA Medical Center',
                'serviceConnectedDisability' => 30,
                'currentStatus' => 'string',
                'appointmentStatus' => 'Completed',
                'externalAppointmentId' => '12345678-0000-0000-0000-000000000003',
                'associatedClaimId' => nil,
                'associatedClaimNumber' => nil,
                'isCompleted' => true
              }
            ]
          }
        ]
      end

      expected_ids = %w[uuid1 uuid2 uuid3]

      client = TravelPay::AppointmentsClient.new
      appts_response = client.get_all_appointments('veis_token', 'btsss_token', { 'excludeWithClaims' => true })
      actual_appt_ids = appts_response.body['data'].pluck('id')

      expect(actual_appt_ids).to eq(expected_ids)
    end

    it 'returns a response with all appointments' do
      @stubs.get('/api/v1.1/appointments') do
        [
          200,
          {},
          {
            'data' => [
              {
                'id' => 'uuid1',
                'appointmentSource' => 'API',
                'appointmentDateTime' => '2024-01-01T16:45:34.465Z',
                'appointmentName' => 'string',
                'appointmentType' => 'EnvironmentalHealth',
                'facilityName' => 'Cheyenne VA Medical Center',
                'serviceConnectedDisability' => 30,
                'currentStatus' => 'string',
                'appointmentStatus' => 'Completed',
                'externalAppointmentId' => '12345678-0000-0000-0000-000000000001',
                'associatedClaimId' => nil,
                'associatedClaimNumber' => nil,
                'isCompleted' => true
              },
              {
                'id' => 'uuid2',
                'appointmentSource' => 'API',
                'appointmentDateTime' => '2024-03-01T16:45:34.465Z',
                'appointmentName' => 'string',
                'appointmentType' => 'EnvironmentalHealth',
                'facilityName' => 'Cheyenne VA Medical Center',
                'serviceConnectedDisability' => 30,
                'currentStatus' => 'string',
                'appointmentStatus' => 'Completed',
                'externalAppointmentId' => '12345678-0000-0000-0000-000000000002',
                'associatedClaimId' => nil,
                'associatedClaimNumber' => nil,
                'isCompleted' => true
              },
              {
                'id' => 'uuid4',
                'appointmentSource' => 'API',
                'appointmentDateTime' => '2024-02-11T16:45:34.465Z',
                'appointmentName' => 'string',
                'appointmentType' => 'EnvironmentalHealth',
                'facilityName' => 'Cheyenne VA Medical Center',
                'serviceConnectedDisability' => 30,
                'currentStatus' => 'string',
                'appointmentStatus' => 'Completed',
                'externalAppointmentId' => '12345678-0000-0000-0000-000000000004',
                'associatedClaimId' => 'uuid4',
                'associatedClaimNumber' => 'TC0000000000004',
                'isCompleted' => true
              }
            ]
          }
        ]
      end

      expected_ids = %w[uuid1 uuid2 uuid4]

      client = TravelPay::AppointmentsClient.new
      appts_response = client.get_all_appointments('veis_token', 'btsss_token')
      actual_appt_ids = appts_response.body['data'].pluck('id')

      expect(actual_appt_ids).to eq(expected_ids)
    end
  end
end
