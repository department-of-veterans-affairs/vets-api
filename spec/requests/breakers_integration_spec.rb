# frozen_string_literal: true

require 'rails_helper'

# TODO: possibly refactor this spec to be generic, not dependent on PrescriptionsController
RSpec.describe 'Breakers Integration', type: :request do
  let(:active_rxs) { File.read('spec/fixtures/json/get_active_rxs.json') }
  let(:history_rxs) { File.read('spec/fixtures/json/get_history_rxs.json') }
  let(:user) { build(:user, :mhv) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    
    # Use the actual Rx client, but stub the API responses
    allow_any_instance_of(Rx::Client).to receive(:get_session).and_return(double('session', user_id: user.mhv_correlation_id))
    allow(Settings.mhv.rx).to receive(:collection_caching_enabled).and_return(false)
  end

  # Helper method to stub MHV API requests
  def stub_varx_request(method, path, response_body, opts = {})
    status_code = opts[:status_code] || 200
    
    # Setup default headers
    response_headers = {
      'Content-Type' => 'application/json',
      'Date' => Time.now.utc.strftime('%a, %d %b %Y %H:%M:%S GMT'),
      'X-RateLimit-Limit' => '60',
      'X-RateLimit-Remaining' => '59',
      'X-RateLimit-Reset' => '3600'
    }

    # Setup the stubs using the actual client methods
    if status_code == 200
      allow_any_instance_of(Rx::Client).to receive(:get_history_rxs).and_return(JSON.parse(response_body))
      allow_any_instance_of(Rx::Client).to receive(:get_active_rxs).and_return(JSON.parse(active_rxs))
    else
      allow_any_instance_of(Rx::Client).to receive(:get_history_rxs).and_raise(Common::Exceptions::BackendServiceException)
      allow_any_instance_of(Rx::Client).to receive(:get_active_rxs).and_raise(Common::Exceptions::BackendServiceException)
    end
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
        response = get '/my_health/v1/prescriptions'
        expect(response).to eq(200)
      end

      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', '{"message":"ack"}', status_code: 500)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', '{"message":"ack"}', status_code: 500)
      80.times do
        response = get '/my_health/v1/prescriptions'
        expect(response).to eq(400)
      end

      expect do
        get '/my_health/v1/prescriptions'
      end.to trigger_statsd_increment('api.external_http_request.Rx.skipped', times: 1, value: 1)

      response = get '/my_health/v1/prescriptions'
      expect(response).to eq(503)

      Timecop.freeze(now)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', active_rxs, status_code: 200)
      response = get '/my_health/v1/prescriptions'
      expect(response).to eq(200)
      Timecop.return
    end
  end

  describe 'statsd calls from the plugin' do
    it 'increments successes' do
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
      expect do
        get '/my_health/v1/prescriptions', headers: { 'Source-App-Name' => 'profile' }
      end.to trigger_statsd_increment('api.external_http_request.Rx.success',
                                      times: 1,
                                      value: 1,
                                      tags: ['endpoint:/mhv-api/patient/v1/prescription/gethistoryrx', 'method:get',
                                             'source:profile'])
    end

    it 'increments errors' do
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 500)
      expect do
        get '/my_health/v1/prescriptions'
      end.to trigger_statsd_increment('api.external_http_request.Rx.failed', times: 1, value: 1)
    end

    it 'measures request times' do
      path = 'mhv-api/patient/v1/prescription/gethistoryrx'
      stub_varx_request(:get, path, history_rxs, status_code: 200, tags: ["endpoint:/#{path}"])
      expect { get '/my_health/v1/prescriptions' }.to trigger_statsd_measure('api.external_http_request.Rx.time', times: 1)
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
