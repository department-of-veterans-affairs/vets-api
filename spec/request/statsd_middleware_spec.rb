# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
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
  let(:mhv_account) { double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, accessible?: true) }
  let(:user) { build(:user, :mhv) }
  let(:now) { Time.current }

  before(:each) do
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_token).and_return(:true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Rx::Client).to receive(:get_session).and_return(session)
    Timecop.freeze(now)
  end

  it 'sends status data to statsd' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    tags = %w(controller:v0/prescriptions action:index status:200)
    expect do
      get '/v0/prescriptions'
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags: tags, times: 1, value: 1)
  end

  it 'sends duration data to statsd' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    tags = %w(controller:v0/prescriptions action:index)
    expect do
      get '/v0/prescriptions'
    end.to trigger_statsd_measure(StatsdMiddleware::DURATION_KEY, tags: tags, times: 1, value: 0.0)
  end

  it 'handles a missing route correctly' do
    tags = %w(controller:application action:routing_error status:404)
    expect do
      get '/v0/blahblah'
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags: tags, times: 1, value: 1)
  end

  it 'provides duration for missing routes' do
    tags = %w(controller:application action:routing_error)
    expect do
      get '/v0/blahblah'
    end.to trigger_statsd_measure(StatsdMiddleware::DURATION_KEY, tags: tags, times: 1, value: 0.0)
  end
end
