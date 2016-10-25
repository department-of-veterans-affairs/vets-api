# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'

RSpec.describe 'breakers', type: :request do
  include Rx::ClientHelpers

  let(:active_rxs) { File.read('spec/support/fixtures/get_active_rxs.json') }
  let(:history_rxs) { File.read('spec/support/fixtures/get_history_rxs.json') }
  let(:session) do
    Rx::ClientSession.new(
      user_id: '123',
      expires_at: 3.weeks.from_now,
      token: Rx::ClientHelpers::TOKEN
    )
  end

  before(:each) do
    use_authenticated_current_user(current_user: build(:prescription_user))
    allow_any_instance_of(Rx::Client).to receive(:get_session).and_return(session)
  end

  context 'integration test for breakers' do
    it 'raises a breakers exception after 50% failure rate' do
      now = Time.current
      start_time = now - 120
      Timecop.freeze(start_time)

      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', active_rxs, status_code: 200)
      20.times do
        response = get '/v0/prescriptions'
        expect(response).to eq(200)
      end

      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', '{"message":"ack"}', status_code: 500)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', '{"message":"ack"}', status_code: 500)
      20.times do
        response = get '/v0/prescriptions'
        expect(response).to eq(400)
      end

      response = get '/v0/prescriptions'
      expect(response).to eq(503)

      Timecop.freeze(now)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', active_rxs, status_code: 200)
      response = get '/v0/prescriptions'
      expect(response).to eq(200)
    end
  end
end
