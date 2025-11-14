# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::Middleware::Response::Errors do
  let(:middleware) { described_class.new(->(env) { env }) }
  let(:env) do
    Faraday::Env.new.tap do |e|
      e.status = status
      e.response_headers = headers
    end
  end
  let(:headers) { {} }

  before do
    RequestStore.clear!
  end

  describe '#on_complete' do
    context 'when response is successful (2xx)' do
      let(:status) { 200 }

      context 'when X-Wellhive-Trace-Id header is present' do
        let(:headers) { { 'x-wellhive-trace-id' => 'test-trace-id-123' } }

        it 'stores the trace ID in RequestStore' do
          middleware.on_complete(env)
          expect(RequestStore.store['eps_trace_id']).to eq('test-trace-id-123')
        end

        it 'does not raise an error' do
          expect { middleware.on_complete(env) }.not_to raise_error
        end
      end

      context 'when X-Wellhive-Trace-Id header is missing' do
        let(:headers) { {} }

        it 'does not store anything in RequestStore' do
          middleware.on_complete(env)
          expect(RequestStore.store['eps_trace_id']).to be_nil
        end

        it 'does not raise an error' do
          expect { middleware.on_complete(env) }.not_to raise_error
        end
      end
    end

    context 'when response is an error (4xx/5xx)' do
      let(:status) { 500 }

      context 'when X-Wellhive-Trace-Id header is present' do
        let(:headers) { { 'x-wellhive-trace-id' => 'error-trace-id-456' } }

        it 'stores the trace ID in RequestStore before raising' do
          expect { middleware.on_complete(env) }.to raise_error(VAOS::Exceptions::BackendServiceException)
          expect(RequestStore.store['eps_trace_id']).to eq('error-trace-id-456')
        end

        it 'raises VAOS::Exceptions::BackendServiceException' do
          expect { middleware.on_complete(env) }.to raise_error(VAOS::Exceptions::BackendServiceException)
        end
      end

      context 'when X-Wellhive-Trace-Id header is missing' do
        let(:headers) { {} }

        it 'does not store anything in RequestStore' do
          expect { middleware.on_complete(env) }.to raise_error(VAOS::Exceptions::BackendServiceException)
          expect(RequestStore.store['eps_trace_id']).to be_nil
        end

        it 'raises VAOS::Exceptions::BackendServiceException' do
          expect { middleware.on_complete(env) }.to raise_error(VAOS::Exceptions::BackendServiceException)
        end
      end
    end

    context 'when trace ID value is an array' do
      let(:status) { 200 }
      let(:headers) { { 'x-wellhive-trace-id' => %w[first-id second-id] } }

      it 'stores the first element from the array' do
        middleware.on_complete(env)
        expect(RequestStore.store['eps_trace_id']).to eq('first-id')
      end
    end

    context 'when trace ID value is empty string' do
      let(:status) { 200 }
      let(:headers) { { 'x-wellhive-trace-id' => '' } }

      it 'does not store anything in RequestStore' do
        middleware.on_complete(env)
        expect(RequestStore.store['eps_trace_id']).to be_nil
      end
    end

    context 'when trace ID value is whitespace only' do
      let(:status) { 200 }
      let(:headers) { { 'x-wellhive-trace-id' => '   ' } }

      it 'does not store anything in RequestStore' do
        middleware.on_complete(env)
        expect(RequestStore.store['eps_trace_id']).to be_nil
      end
    end

    context 'when response_headers is nil' do
      let(:status) { 200 }
      let(:env) do
        Faraday::Env.new.tap do |e|
          e.status = status
          e.response_headers = nil
        end
      end

      it 'does not raise an error' do
        expect { middleware.on_complete(env) }.not_to raise_error
      end

      it 'does not store anything in RequestStore' do
        middleware.on_complete(env)
        expect(RequestStore.store['eps_trace_id']).to be_nil
      end
    end
  end

  describe 'middleware registration' do
    it 'registers as :eps_errors' do
      expect(Faraday::Response.lookup_middleware(:eps_errors)).to eq(described_class)
    end
  end
end
