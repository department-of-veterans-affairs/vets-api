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
end
