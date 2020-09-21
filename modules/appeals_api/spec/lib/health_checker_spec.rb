# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/health_checker'

describe AppealsApi::HealthChecker do
  subject { described_class.new }

  let(:client_stub) do
    caseflow = instance_double(Caseflow::Service)
    allow(Caseflow::Service).to receive(:new).and_return(caseflow)
    caseflow
  end

  let(:faraday_response) { instance_double('Faraday::Response') }

  describe '#services_are_healthy?' do
    context 'when caseflow is healthy' do
      it 'returns true' do
        allow(faraday_response).to receive(:body).and_return({ 'healthy' => true })
        allow(client_stub).to receive(:healthcheck).and_return(faraday_response)

        expect(subject).to be_services_are_healthy
      end
    end

    context 'when caseflow is not healthy' do
      it 'returns false' do
        allow(faraday_response).to receive(:body).and_return({ 'healthy' => false })
        allow(client_stub).to receive(:healthcheck).and_return(faraday_response)

        expect(subject).not_to be_services_are_healthy
      end
    end
  end

  describe '#caseflow_is_healthy?' do
    context 'when healthy' do
      it 'returns true' do
        allow(faraday_response).to receive(:body).and_return({ 'healthy' => true })
        allow(client_stub).to receive(:healthcheck).and_return(faraday_response)

        expect(subject).to be_caseflow_is_healthy
      end
    end

    context 'when not healthy' do
      it 'returns false' do
        allow(faraday_response).to receive(:body).and_return({ 'healthy' => false })
        allow(client_stub).to receive(:healthcheck).and_return(faraday_response)

        expect(subject).not_to be_caseflow_is_healthy
      end
    end
  end
end
