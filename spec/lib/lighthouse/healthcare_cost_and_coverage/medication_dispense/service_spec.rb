# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/healthcare_cost_and_coverage/medication_dispense/service'

RSpec.describe Lighthouse::HealthcareCostAndCoverage::MedicationDispense::Service do
  subject(:svc) { described_class.new(icn) }

  let(:icn)    { '43000199' }
  let(:config) { instance_double(Lighthouse::HealthcareCostAndCoverage::Configuration) }
  let(:bundle) { { 'resourceType' => 'Bundle', 'type' => 'searchset', 'entry' => [] } }
  let(:response_double) { instance_double(Faraday::Response, body: bundle) }

  before do
    allow(described_class).to receive(:configuration).and_return(config)
  end

  describe '#list' do
    context 'when id is provided' do
      let(:id) { '4-1abU4wmNqduNeO' }

      it 'queries by _id only and returns the body' do
        expect(config).to receive(:get).with(
          'r4/MedicationDispense',
          params: { _id: id },
          icn:
        ).and_return(response_double)

        expect(svc.list(id:)).to eq(bundle)
      end
    end

    context 'when id is not provided' do
      it 'defaults to patient search using the service ICN' do
        expect(config).to receive(:get).with(
          'r4/MedicationDispense',
          params: { patient: icn },
          icn:
        ).and_return(response_double)

        expect(svc.list).to eq(bundle)
      end

      it 'passes through extra query params (e.g., _count, page)' do
        expect(config).to receive(:get).with(
          'r4/MedicationDispense',
          params: { patient: icn, _count: 10, page: 2 },
          icn:
        ).and_return(response_double)

        expect(svc.list(_count: 10, page: 2)).to eq(bundle)
      end

      it 'uses an explicitly provided patient if given' do
        expect(config).to receive(:get).with(
          'r4/MedicationDispense',
          params: { patient: 'Patient/43000199' },
          icn:
        ).and_return(response_double)

        expect(svc.list(patient: 'Patient/43000199')).to eq(bundle)
      end
    end
  end
end
