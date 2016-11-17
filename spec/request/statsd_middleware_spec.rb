# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'
require 'statsd_middleware'

# TODO: possibly refactor this spec to be generic, not dependent on PrescriptionsController
RSpec.describe StatsdMiddleware, type: :request do
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
  let(:user) { build(:mhv_user) }

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate_token).and_return(:true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Rx::Client).to receive(:get_session).and_return(session)
  end

  it 'sends data to statsd' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs, status_code: 200)
    key = 'api.external.request#status=200,controller=v0/prescriptions,action=index'
    expect do
      get '/v0/prescriptions'
    end.to trigger_statsd_increment(key, times: 1, value: 1)
  end
end
