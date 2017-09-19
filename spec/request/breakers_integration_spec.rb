# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'

# TODO: possibly refactor this spec to be generic, not dependent on PrescriptionsController
RSpec.describe 'breakers', type: :request do
  include Rx::ClientHelpers

  let(:active_rxs) { File.read('spec/fixtures/json/get_active_rxs.json') }
  let(:history_rxs) { File.read('spec/fixtures/json/get_history_rxs.json') }
  let(:session) do
    Rx::ClientSession.new(
      user_id: '123',
      expires_at: 3.weeks.from_now,
      token: Rx::ClientHelpers::TOKEN
    )
  end
  let(:mhv_account) { double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, upgraded?: true) }
  let(:user) { build(:mhv_user) }

  before(:each) do
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_token).and_return(:true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Rx::Client).to receive(:get_session).and_return(session)
  end

  after(:all) do
    # Breakers doesn't have a global 'reset', so just blow away the connection's db entirely.
    # Not clearing the breakers would cause subsequent RX calls to fail after the breaker is
    # triggered in this group.

    # fakeredis/rspec has a `before` callback, but it's for the suite, not each example. Oops.
    Breakers.client.redis_connection.redis.flushdb
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

  describe 'statsd calls from the plugin' do
    it 'increments successes' do
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
      expect do
        get '/v0/prescriptions'
      end.to trigger_statsd_increment('api.external_http_request.Rx.success', times: 1, value: 1)
    end

    it 'increments errors' do
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 500)
      expect do
        get '/v0/prescriptions'
      end.to trigger_statsd_increment('api.external_http_request.Rx.failed', times: 1, value: 1)
    end

    it 'measures request times' do
      path = 'mhv-api/patient/v1/prescription/gethistoryrx'
      stub_varx_request(:get, path, history_rxs, status_code: 200, tags: ['endpoint:/' + path])
      expect { get '/v0/prescriptions' }.to trigger_statsd_measure('api.external_http_request.Rx.time', times: 1)
    end
  end
end
