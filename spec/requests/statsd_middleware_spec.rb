# frozen_string_literal: true

require 'rails_helper'
require 'statsd_middleware'

RSpec.describe StatsdMiddleware, type: :request do
  before do
    statsd_controller = Class.new(ApplicationController) do
      skip_before_action :authenticate

      def statsd_test
        head :ok
      end
    end
    stub_const('StatsdController', statsd_controller)
    Rails.application.routes.draw do
      get '/statsd_test' => 'statsd#statsd_test'

      match '*path', to: 'application#routing_error', via: %i[get post put patch delete]
    end
    Timecop.freeze
  end

  after do
    Rails.application.reload_routes!
    Timecop.return
  end

  it 'sends status data to statsd' do
    tags = %w[controller:statsd action:statsd_test source_app:not_provided status:200]
    expect do
      get '/statsd_test'
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags:, times: 1, value: 1)
  end

  it 'sends duration data to statsd' do
    tags = %w[controller:statsd action:statsd_test source_app:not_provided]
    expect do
      get '/statsd_test'
    end.to trigger_statsd_measure(StatsdMiddleware::DURATION_KEY, tags:, times: 1, value: 0.0)
  end

  it 'sends db_runtime data to statsd' do
    tags = %w[controller:statsd action:statsd_test status:200]
    expect do
      get '/statsd_test'
    end.to trigger_statsd_measure('api.request.db_runtime', tags:, times: 1, value: be_between(0, 100))
  end

  it 'sends view_runtime data to statsd' do
    tags = %w[controller:statsd action:statsd_test status:200]
    expect do
      get '/statsd_test'
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
    tags = %w[controller:statsd action:statsd_test source_app:profile status:200]
    expect do
      get '/statsd_test', headers: { 'Source-App-Name' => 'profile' }
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags:, times: 1)
  end

  it 'sends undefined to statsd when source_app is undefined' do
    tags = %w[controller:statsd action:statsd_test source_app:undefined status:200]
    expect do
      get '/statsd_test', headers: { 'Source-App-Name' => 'undefined' }
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags:, times: 1)
  end

  it 'uses not_in_allowlist for source_app when the value is not in allow list' do
    tags = %w[controller:statsd action:statsd_test source_app:not_in_allowlist status:200]
    expect do
      get '/statsd_test', headers: { 'Source-App-Name' => 'foo' }
    end.to trigger_statsd_increment(StatsdMiddleware::STATUS_KEY, tags:, times: 1)
  end

  it 'logs a warning for unrecognized source_app_name headers' do
    expect(Rails.logger).to receive(:warn).once.with(
      'Unrecognized value for HTTP_SOURCE_APP_NAME request header... [foo]'
    )
    get '/statsd_test', headers: { 'Source-App-Name' => 'foo' }
  end
end
