# frozen_string_literal: true

require 'rails_helper'
require 'eps/middleware/response/trace_id_extractor'

describe Eps::Middleware::Response::TraceIdExtractor do
  let(:middleware) { described_class.new }

  describe '#on_complete' do
    let(:env) { double('Faraday::Env') }

    context 'when response headers contain the trace ID' do
      let(:trace_id) { 'test-trace-id-123' }
      let(:response_headers) { { 'x-wellhive-trace-id' => trace_id } }

      before do
        allow(env).to receive(:respond_to?).with(:response_headers).and_return(true)
        allow(env).to receive(:response_headers).and_return(response_headers)
      end

      it 'extracts and stores the trace ID in RequestStore' do
        expect(RequestStore.store).to receive(:[]=).with('eps_trace_id', trace_id)

        middleware.on_complete(env)
      end
    end

    context 'when response headers contain the trace ID as an array' do
      let(:trace_id) { 'test-trace-id-456' }
      let(:response_headers) { { 'x-wellhive-trace-id' => [trace_id, 'other-value'] } }

      before do
        allow(env).to receive(:respond_to?).with(:response_headers).and_return(true)
        allow(env).to receive(:response_headers).and_return(response_headers)
      end

      it 'extracts the first element of the array and stores it' do
        expect(RequestStore.store).to receive(:[]=).with('eps_trace_id', trace_id)

        middleware.on_complete(env)
      end
    end

    context 'when response headers do not contain the trace ID' do
      let(:response_headers) { { 'content-type' => 'application/json' } }

      before do
        allow(env).to receive(:respond_to?).with(:response_headers).and_return(true)
        allow(env).to receive(:response_headers).and_return(response_headers)
      end

      it 'does not store anything in RequestStore' do
        expect(RequestStore.store).not_to receive(:[]=)

        middleware.on_complete(env)
      end
    end

    context 'when env does not have response_headers method' do
      before do
        allow(env).to receive(:respond_to?).with(:response_headers).and_return(false)
      end

      it 'does not store anything in RequestStore' do
        expect(RequestStore.store).not_to receive(:[]=)

        middleware.on_complete(env)
      end
    end

    context 'when response_headers is nil' do
      before do
        allow(env).to receive(:respond_to?).with(:response_headers).and_return(true)
        allow(env).to receive(:response_headers).and_return(nil)
      end

      it 'does not store anything in RequestStore' do
        expect(RequestStore.store).not_to receive(:[]=)

        middleware.on_complete(env)
      end
    end

    context 'when trace ID value is nil' do
      let(:response_headers) { { 'x-wellhive-trace-id' => nil } }

      before do
        allow(env).to receive(:respond_to?).with(:response_headers).and_return(true)
        allow(env).to receive(:response_headers).and_return(response_headers)
      end

      it 'does not store anything in RequestStore' do
        expect(RequestStore.store).not_to receive(:[]=)

        middleware.on_complete(env)
      end
    end

    context 'when trace ID value is empty string' do
      let(:response_headers) { { 'x-wellhive-trace-id' => '' } }

      before do
        allow(env).to receive(:respond_to?).with(:response_headers).and_return(true)
        allow(env).to receive(:response_headers).and_return(response_headers)
      end

      it 'does not store anything in RequestStore' do
        expect(RequestStore.store).not_to receive(:[]=)

        middleware.on_complete(env)
      end
    end
  end

  describe 'TRACE_ID_HEADER constant' do
    it 'is defined as the expected header name' do
      expect(described_class::TRACE_ID_HEADER).to eq('x-wellhive-trace-id')
    end
  end
end
