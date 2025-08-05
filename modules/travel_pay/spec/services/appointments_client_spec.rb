# frozen_string_literal: true

require 'rails_helper'

describe TravelPay::AppointmentsClient do
  let(:user) { build(:user) }

  let(:tokens) { %w[veis_token btsss_token] }

  let(:data) do
    [
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
  end

  before do
    @stubs = Faraday::Adapter::Test::Stubs.new

    conn = Faraday.new do |c|
      c.adapter(:test, @stubs)
      c.response :json
      c.request :json
    end

    allow_any_instance_of(TravelPay::AppointmentsClient).to receive(:connection).and_return(conn)
    allow(StatsD).to receive(:measure)
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
    expected_log_prefix = 'travel_pay.appointments.response_time'
    expected_log_tag = ['travel_pay:get_all']

    it 'returns a response only with appointments with no claims' do
      @stubs.get('/api/v2/appointments?excludeWithClaims=true') do
        [
          200,
          {},
          {
            'data' => data
          }
        ]
      end

      expected_ids = %w[uuid1 uuid2 uuid3]

      client = TravelPay::AppointmentsClient.new
      appts_response = client.get_all_appointments(*tokens, { 'excludeWithClaims' => true })
      actual_appt_ids = appts_response.body['data'].pluck('id')

      expect(StatsD).to have_received(:measure)
        .with(expected_log_prefix,
              kind_of(Numeric),
              tags: expected_log_tag)
      expect(actual_appt_ids).to eq(expected_ids)
    end

    it 'returns a response with all appointments' do
      @stubs.get('/api/v2/appointments') do
        [
          200,
          {},
          {
            'data' => data
          }
        ]
      end

      expected_ids = %w[uuid1 uuid2 uuid3]

      client = TravelPay::AppointmentsClient.new
      appts_response = client.get_all_appointments(*tokens)
      actual_appt_ids = appts_response.body['data'].pluck('id')

      expect(StatsD).to have_received(:measure)
        .with(expected_log_prefix,
              kind_of(Numeric),
              tags: expected_log_tag)
      expect(actual_appt_ids).to eq(expected_ids)
    end
  end
end
