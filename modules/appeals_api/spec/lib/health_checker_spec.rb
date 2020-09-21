# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/health_checker'

describe AppealsApi::HealthChecker do
  subject { described_class }

  describe '.services_are_healthy?' do
    context 'when caseflow is healthy' do
      it 'returns true' do
        allow(described_class).to receive(:caseflow_is_healthy?).and_return(true)
        expect(subject.services_are_healthy?).to be_truthy
      end
    end

    context 'when caseflow is not healthy' do
      it 'returns false' do
        allow(described_class).to receive(:caseflow_is_healthy?).and_return(false)
        expect(subject.services_are_healthy?).to be_falsey
      end
    end
  end

  describe '.caseflow_is_healthy?' do
    let(:client_stub) { instance_double(Caseflow::Service) }
    let(:faraday_response) { instance_double('Faraday::Response') }

    context 'when healthy' do
      it 'returns true' do
        allow(Caseflow::Service).to receive(:new).and_return(client_stub)
        allow(faraday_response).to receive(:body).and_return({ 'healthy' => true })
        allow(client_stub).to receive(:healthcheck).and_return(faraday_response)
        expect(subject.caseflow_is_healthy?).to be_truthy
      end
    end

    context 'when not healthy' do
      it 'returns false' do
        allow(Caseflow::Service).to receive(:new).and_return(client_stub)
        allow(faraday_response).to receive(:body).and_return({ 'healthy' => false })
        allow(client_stub).to receive(:healthcheck).and_return(faraday_response)
        expect(subject.caseflow_is_healthy?).to be_falsey
      end
    end
  end
end
