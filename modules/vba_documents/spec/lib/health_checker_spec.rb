# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/health_checker'

describe VBADocuments::HealthChecker do
  subject { described_class.new }

  describe '#services_are_healthy?' do
    context 'when central mail is healthy' do
      before { allow(CentralMail::Service).to receive(:service_is_up?).and_return(true) }

      it 'returns true' do
        expect(subject.services_are_healthy?).to be(true)
      end
    end

    context 'when central mail is not healthy' do
      before { allow(CentralMail::Service).to receive(:service_is_up?).and_return(false) }

      it 'returns false' do
        expect(subject.services_are_healthy?).to be(false)
      end
    end
  end

  describe '#healthy_service?' do
    context 'when service is recognized' do
      let(:service_name) { 'central_mail' }

      context 'when healthy' do
        before { allow(CentralMail::Service).to receive(:service_is_up?).and_return(true) }

        it 'returns true' do
          expect(subject.healthy_service?(service_name)).to be(true)
        end
      end

      context 'when not healthy' do
        before { allow(CentralMail::Service).to receive(:service_is_up?).and_return(false) }

        it 'returns false' do
          expect(subject.healthy_service?(service_name)).to be(false)
        end
      end
    end

    context 'when service is not recognized' do
      let(:service_name) { 'unknown_service' }

      it 'raises an exception' do
        expect { subject.healthy_service?(service_name) }.to raise_error do |error|
          expect(error).to be_a(StandardError)
          expect(error.message).to eq("VBADocuments::HealthChecker doesn't recognize #{service_name}")
        end
      end
    end
  end
end
