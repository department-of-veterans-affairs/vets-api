# frozen_string_literal: true

require 'rails_helper'

# Tests for config/initializers/committee.rb
RSpec.describe CommitteeErrorRouting do # rubocop:disable RSpec/SpecFilePathFormat
  describe '.monitor_for_request' do
    subject(:monitor) { described_class.monitor_for_request(request) }

    context 'when path matches /v0/form21p530a' do
      let(:request) { instance_double(Rack::Request, path: '/v0/form21p530a/submit') }

      it 'returns a Form21p530a::Monitor instance' do
        expect(monitor).to be_a(Form21p530a::Monitor)
      end
    end

    context 'when path matches /v0/form214192' do
      let(:request) { instance_double(Rack::Request, path: '/v0/form214192/submit') }

      it 'returns a Form214192::Monitor instance' do
        expect(monitor).to be_a(Form214192::Monitor)
      end
    end

    context 'when path does not match any form pattern' do
      let(:request) { instance_double(Rack::Request, path: '/v0/other_endpoint') }

      it 'returns nil' do
        expect(monitor).to be_nil
      end
    end

    context 'when path is a different v0 form' do
      let(:request) { instance_double(Rack::Request, path: '/v0/form526') }

      it 'returns nil' do
        expect(monitor).to be_nil
      end
    end
  end

  describe 'ERROR_HANDLER' do
    subject(:error_handler) { ERROR_HANDLER }

    let(:env) do
      {
        'REQUEST_METHOD' => 'POST',
        'PATH_INFO' => path,
        'rack.input' => StringIO.new,
        'SOURCE_APP' => 'test-app'
      }
    end

    after do
      # Clear CommitteeContext for test isolation (Rails auto-resets after each request in production)
      CommitteeContext.reset
    end

    context 'with form21p530a path' do
      let(:path) { '/v0/form21p530a/submit' }
      let(:error) { Committee::InvalidRequest.new('validation error') }

      it 'routes to Form21p530a::Monitor' do
        monitor_instance = instance_double(Form21p530a::Monitor)
        allow(Form21p530a::Monitor).to receive(:new).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_request_validation_error)

        error_handler.call(error, env)

        expect(monitor_instance).to have_received(:track_request_validation_error).with(
          error:,
          request: kind_of(Rack::Request)
        )
      end

      it 'populates CommitteeContext with controller and action' do
        monitor_instance = instance_double(Form21p530a::Monitor)
        allow(Form21p530a::Monitor).to receive(:new).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_request_validation_error)

        error_handler.call(error, env)

        expect(CommitteeContext.controller).to eq('v0/form21p530a')
        expect(CommitteeContext.action).to eq('create')
      end
    end

    context 'with form214192 path' do
      let(:path) { '/v0/form214192/submit' }
      let(:error) { Committee::InvalidRequest.new('validation error') }

      it 'routes to Form214192::Monitor' do
        monitor_instance = instance_double(Form214192::Monitor)
        allow(Form214192::Monitor).to receive(:new).and_return(monitor_instance)
        allow(monitor_instance).to receive(:track_request_validation_error)

        error_handler.call(error, env)

        expect(monitor_instance).to have_received(:track_request_validation_error).with(
          error:,
          request: kind_of(Rack::Request)
        )
      end
    end

    context 'with unmatched path' do
      let(:path) { '/v0/other_endpoint' }
      let(:error) { Committee::InvalidRequest.new('validation error') }

      it 'uses StatsD fallback for request validation' do
        expect(StatsD).to receive(:increment).with(
          'api.committee.validation_error',
          tags: array_including(
            'error_type:request_validation',
            "path:#{path}",
            'source_app:test-app'
          )
        )

        error_handler.call(error, env)
      end
    end

    context 'with response validation error' do
      let(:path) { '/v0/form21p530a/submit' }
      let(:error) { Committee::InvalidResponse.new('response validation error') }

      it 'uses StatsD fallback even for matched paths' do
        expect(StatsD).to receive(:increment).with(
          'api.committee.validation_error',
          tags: array_including(
            'error_type:response_validation',
            "path:#{path}",
            'source_app:test-app'
          )
        )

        error_handler.call(error, env)
      end
    end

    context 'with unknown source app' do
      let(:path) { '/v0/other_endpoint' }
      let(:error) { Committee::InvalidRequest.new('validation error') }
      let(:env) do
        {
          'REQUEST_METHOD' => 'POST',
          'PATH_INFO' => path,
          'rack.input' => StringIO.new
        }
      end

      it 'defaults source_app to unknown' do
        expect(StatsD).to receive(:increment).with(
          'api.committee.validation_error',
          tags: array_including('source_app:unknown')
        )

        error_handler.call(error, env)
      end
    end
  end

  describe '.populate_path_parameters' do
    let(:env) do
      {
        'REQUEST_METHOD' => 'POST',
        'PATH_INFO' => '/v0/form21p530a',
        'rack.input' => StringIO.new
      }
    end

    context 'when path_parameters not already set' do
      it 'populates controller and action from routes' do
        described_class.populate_path_parameters(env)

        expect(env['action_dispatch.request.path_parameters']).to include(
          controller: 'v0/form21p530a',
          action: 'create'
        )
      end
    end

    context 'when path_parameters already set' do
      before do
        env['action_dispatch.request.path_parameters'] = { controller: 'existing', action: 'existing' }
      end

      it 'does not overwrite existing path_parameters' do
        described_class.populate_path_parameters(env)

        expect(env['action_dispatch.request.path_parameters']).to eq(
          controller: 'existing',
          action: 'existing'
        )
      end
    end

    context 'when route matching fails' do
      let(:env) do
        {
          'REQUEST_METHOD' => 'POST',
          'PATH_INFO' => '/invalid/route/path',
          'rack.input' => StringIO.new
        }
      end

      it 'does not raise an error' do
        expect { described_class.populate_path_parameters(env) }.not_to raise_error
      end

      it 'sets path_parameters to routing_error for unmatched routes' do
        described_class.populate_path_parameters(env)

        expect(env['action_dispatch.request.path_parameters']).to include(
          controller: 'application',
          action: 'routing_error'
        )
      end
    end
  end

  context 'when Committee validation fails', type: :request do
    after do
      # Clear CommitteeContext for test isolation (Rails auto-resets after each request in production)
      CommitteeContext.reset
    end

    let(:invalid_payload) do
      { data: { attributes: { claimant: { first: 'John' } } } }.to_json
    end

    it 'sends statsd metrics with controller and action tags for form21p530a' do
      expected_tags = [
        'controller:v0/form21p530a',
        'action:create',
        'source_app:21p-530a-interment-allowance',
        'status:422'
      ]

      # Allow the form-specific monitor metrics
      allow(StatsD).to receive(:increment).and_call_original

      # Expect StatsdMiddleware to be called with controller/action tags
      expect(StatsD).to receive(:increment)
        .with(StatsdMiddleware::STATUS_KEY, hash_including(tags: expected_tags))
        .and_call_original

      post '/v0/form21p530a',
           params: invalid_payload,
           headers: { 'Content-Type': 'application/json', 'Source-App-Name': '21p-530a-interment-allowance' }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'sends duration metrics with controller and action tags for form21p530a' do
      expected_tags = [
        'controller:v0/form21p530a',
        'action:create',
        'source_app:21p-530a-interment-allowance'
      ]

      # Allow all StatsD calls
      allow(StatsD).to receive(:increment).and_call_original
      allow(StatsD).to receive(:measure).and_call_original
      allow(StatsD).to receive(:distribution).and_call_original

      # Expect StatsdMiddleware to be called with controller/action tags
      expect(StatsD).to receive(:measure)
        .with(StatsdMiddleware::DURATION_KEY, kind_of(Numeric), hash_including(tags: expected_tags))
        .and_call_original

      expect(StatsD).to receive(:distribution)
        .with(StatsdMiddleware::DURATION_DISTRIBUTION_KEY, kind_of(Numeric), hash_including(tags: expected_tags))
        .and_call_original

      post '/v0/form21p530a',
           params: invalid_payload,
           headers: { 'Content-Type': 'application/json', 'Source-App-Name': '21p-530a-interment-allowance' }
    end

    it 'sends statsd metrics with controller and action tags for form214192' do
      expected_tags = [
        'controller:v0/form214192',
        'action:create',
        'source_app:not_provided',
        'status:422'
      ]

      # Allow the form-specific monitor metrics
      allow(StatsD).to receive(:increment).and_call_original

      # Expect StatsdMiddleware to be called with controller/action tags
      expect(StatsD).to receive(:increment)
        .with(StatsdMiddleware::STATUS_KEY, hash_including(tags: expected_tags))
        .and_call_original

      post '/v0/form214192',
           params: invalid_payload,
           headers: { 'Content-Type': 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'includes controller and action in error response meta for form21p530a' do
      post '/v0/form21p530a',
           params: invalid_payload,
           headers: { 'Content-Type': 'application/json', 'Source-App-Name': '21p-530a-interment-allowance' }

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['errors'].first['meta']).to eq(
        'controller' => 'v0/form21p530a',
        'action' => 'create'
      )
    end

    it 'includes controller and action in error response meta for form214192' do
      post '/v0/form214192',
           params: invalid_payload,
           headers: { 'Content-Type': 'application/json' }

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['errors'].first['meta']).to eq(
        'controller' => 'v0/form214192',
        'action' => 'create'
      )
    end
  end
end
