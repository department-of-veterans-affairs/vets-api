# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'
require 'statsd_middleware'

# TODO: possibly refactor this spec to be generic, not dependent on PrescriptionsController
RSpec.describe StatsdMiddleware, type: :request do
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
  let(:user) { build(:user, :mhv) }
  let(:now) { Time.current }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medications_migrate_to_api_gateway).and_return(false)
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Rx::Client).to receive(:get_session).and_return(session)
    Timecop.freeze(now)
  end

  after { Timecop.return }

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
