# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/healthcare_cost_and_coverage/organization/service'

RSpec.describe Lighthouse::HealthcareCostAndCoverage::Organization::Service do
  let(:icn) { '1234567890V123456' }
  let(:service) { described_class.new(icn) }
  let(:response_body) { { 'resourceType' => 'Bundle', 'entry' => [] } }
  let(:faraday_response) { double('Faraday::Response', body: response_body) }

  describe '#initialize' do
    it 'initializes with icn' do
      expect(service).to be_a(described_class)
    end

    it 'raises if icn is blank' do
      expect { described_class.new(nil) }.to raise_error(ArgumentError)
      expect { described_class.new('') }.to raise_error(ArgumentError)
    end
  end

  describe '#read' do
    let(:config) { instance_double(Lighthouse::HealthcareCostAndCoverage::Configuration) }

    before do
      allow(service).to receive(:config).and_return(config)
      allow(config).to receive_messages(
        get: faraday_response,
        base_api_path: 'http://example.test'
      )
    end

    it 'returns a FHIR bundle hash' do
      result = service.read('4-O3d8XK44ejMS')
      expect(result).to eq(response_body)
    end

    it 'passes correct params to config.get' do
      expect(service.send(:config)).to receive(:get).with(
        'r4/Organization',
        {
          params: { _id: '4-O3d8XK44ejMS' },
          icn:
        }
      ).and_return(faraday_response)

      service.read('4-O3d8XK44ejMS')
    end

    context 'when Faraday::TimeoutError is raised' do
      before do
        allow(service.send(:config)).to receive(:get).and_raise(Faraday::TimeoutError.new)
        allow(Lighthouse::ServiceException).to receive(:send_error).and_return(:error_envelope)
      end

      it 'calls handle_error and returns error envelope' do
        expect(service.read('4-O3d8XK44ejMS')).to eq(:error_envelope)
      end
    end

    context 'when Faraday::ClientError is raised' do
      before do
        allow(service.send(:config)).to receive(:get).and_raise(Faraday::ClientError.new('fail'))
        allow(Lighthouse::ServiceException).to receive(:send_error).and_return(:error_envelope)
      end

      it 'calls handle_error and returns error envelope' do
        expect(service.read('4-O3d8XK44ejMS')).to eq(:error_envelope)
      end
    end
  end
end
