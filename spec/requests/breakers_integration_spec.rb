# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'

# TODO: possibly refactor this spec to be generic, not dependent on PrescriptionsController
RSpec.describe 'Breakers Integration', type: :request do
  include Rx::ClientHelpers

  let(:active_rxs) { File.read('spec/fixtures/json/get_active_rxs.json') }
  let(:history_rxs) { File.read('spec/fixtures/json/get_history_rxs.json') }
  let(:user) { build(:user, :mhv) }
  let(:session) do
    Rx::ClientSession.new(
      user_id: user.mhv_correlation_id,
      expires_at: 3.weeks.from_now,
      token: Rx::ClientHelpers::TOKEN
    )
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Rx::Client).to receive(:get_session).and_return(session)
    allow(Settings.mhv.rx).to receive(:collection_caching_enabled).and_return(false)
  end

  after(:all) do
    # Breakers doesn't have a global 'reset', so just blow away the connection's db entirely.
    # Not clearing the breakers would cause subsequent RX calls to fail after the breaker is
    # triggered in this group.

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
      80.times do
        response = get '/v0/prescriptions'
        expect(response).to eq(400)
      end

      expect do
        get '/v0/prescriptions'
      end.to trigger_statsd_increment('api.external_http_request.Rx.skipped', times: 1, value: 1)

      response = get '/v0/prescriptions'
      expect(response).to eq(503)

      Timecop.freeze(now)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', active_rxs, status_code: 200)
      response = get '/v0/prescriptions'
      expect(response).to eq(200)
      Timecop.return
    end
  end

  describe 'statsd calls from the plugin' do
    it 'increments successes' do
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
      expect do
        get '/v0/prescriptions', headers: { 'Source-App-Name' => 'profile' }
      end.to trigger_statsd_increment('api.external_http_request.Rx.success',
                                      times: 1,
                                      value: 1,
                                      tags: ['endpoint:/mhv-api/patient/v1/prescription/gethistoryrx', 'method:get',
                                             'source:profile'])
    end

    it 'increments errors' do
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 500)
      expect do
        get '/v0/prescriptions'
      end.to trigger_statsd_increment('api.external_http_request.Rx.failed', times: 1, value: 1)
    end

    it 'measures request times' do
      path = 'mhv-api/patient/v1/prescription/gethistoryrx'
      stub_varx_request(:get, path, history_rxs, status_code: 200, tags: ["endpoint:/#{path}"])
      expect { get '/v0/prescriptions' }.to trigger_statsd_measure('api.external_http_request.Rx.time', times: 1)
    end
  end

  it 'includes correct tags in background jobs', skip: 'Flaky test noted in commit history' do
    RequestStore.store['additional_request_attributes'] = { 'source' => 'auth' }
    PagerDuty::PollMaintenanceWindows.perform_async
    RequestStore.clear!

    with_settings(Settings.vanotify.services.va_gov, api_key: "testkey-#{SecureRandom.uuid}-#{SecureRandom.uuid}") do
      VCR.use_cassette('pager_duty/success', match_requests_on: %i[method path]) do
        expect do
          PagerDuty::PollMaintenanceWindows.drain
        end.to trigger_statsd_increment('api.external_http_request.PagerDuty.success',
                                        times: 1,
                                        tags: ['endpoint:/maintenance_windows', 'method:get', 'source:auth'])
      end
    end
  end
end
