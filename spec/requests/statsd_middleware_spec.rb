# frozen_string_literal: true

require 'rails_helper'
require 'statsd_middleware'

# TODO: possibly refactor this spec to be generic, not dependent on PrescriptionsController
RSpec.describe StatsdMiddleware, type: :request do
  let(:active_rxs) { File.read('spec/fixtures/json/get_active_rxs.json') }
  let(:history_rxs) { File.read('spec/fixtures/json/get_history_rxs.json') }
  let(:user) { build(:user, :mhv) }
  let(:now) { Time.current }
  let(:mock_client) { double('mock_client') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    
    # Replace the dependency on Rx with a test double
    controller_class = V0::PrescriptionsController
    allow_any_instance_of(controller_class).to receive(:client) do
      mock_client
    end
    
    allow(mock_client).to receive(:get_history_rxs).and_return([])
    Timecop.freeze(now)
  end

  after { Timecop.return }

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

    # Setup the stubs to either succeed or fail
    if status_code == 200
      allow(mock_client).to receive(:get_history_rxs).and_return(JSON.parse(response_body))
    else
      allow(mock_client).to receive(:get_history_rxs).and_raise(Common::Exceptions::BackendServiceException)
    end
  end

  it 'sends status data to statsd' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    tags = %w[controller:v0/prescriptions action:index source_app:not_provided status:200]
    expect do
      get '/v0/prescriptions'
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags:, times: 1, value: 1)
  end

  it 'sends duration data to statsd' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    tags = %w[controller:v0/prescriptions action:index source_app:not_provided]
    expect do
      get '/v0/prescriptions'
    end.to trigger_statsd_measure(StatsdMiddleware::DURATION_KEY, tags:, times: 1, value: 0.0)
  end

  it 'sends db_runtime data to statsd' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    tags = %w[controller:v0/prescriptions action:index status:200]
    expect do
      get '/v0/prescriptions'
    end.to trigger_statsd_measure('api.request.db_runtime', tags:, times: 1, value: be_between(0, 100))
  end

  it 'sends view_runtime data to statsd' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    tags = %w[controller:v0/prescriptions action:index status:200]
    expect do
      get '/v0/prescriptions'
    end.to trigger_statsd_measure('api.request.view_runtime', tags:, times: 1, value: be_between(0, 100))
  end

  it 'handles a missing route correctly' do
    tags = %w[controller:application action:routing_error source_app:not_provided status:404]
    expect do
      get '/v0/blahblah'
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags:, times: 1, value: 1)
  end

  it 'provides duration for missing routes' do
    tags = %w[controller:application action:routing_error source_app:not_provided]
    expect do
      get '/v0/blahblah'
    end.to trigger_statsd_measure(StatsdMiddleware::DURATION_KEY, tags:, times: 1, value: 0.0)
  end

  it 'sends source_app to statsd' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    tags = %w[controller:v0/prescriptions action:index source_app:profile status:200]
    expect do
      get '/v0/prescriptions', headers: { 'Source-App-Name' => 'profile' }
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags:, times: 1)
  end

  it 'sends undefined to statsd when source_app is undefined' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    tags = %w[controller:v0/prescriptions action:index source_app:undefined status:200]
    expect do
      get '/v0/prescriptions', headers: { 'Source-App-Name' => 'undefined' }
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags:, times: 1)
  end

  it 'uses not_in_allowlist for source_app when the value is not in allow list' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    tags = %w[controller:v0/prescriptions action:index source_app:not_in_allowlist status:200]
    expect do
      get '/v0/prescriptions', headers: { 'Source-App-Name' => 'foo' }
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags:, times: 1)
  end

  it 'logs a warning for unrecognized source_app_name headers' do
    expect(Rails.logger).to receive(:warn).once.with(
      'Unrecognized value for HTTP_SOURCE_APP_NAME request header... [foo]'
    )
    get '/v0/prescriptions', headers: { 'Source-App-Name' => 'foo' }
  end
end
