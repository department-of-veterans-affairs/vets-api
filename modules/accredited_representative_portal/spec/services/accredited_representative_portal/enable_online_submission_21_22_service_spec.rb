# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::EnableOnlineSubmission2122Service do
  describe '.call' do
    subject(:call_service) { described_class.call(poa_codes:) }

    context 'with comma-separated string' do
      let!(:org_svs) { Veteran::Service::Organization.create!(poa: 'SVS', name: 'SVS', can_accept_digital_poa_requests: false) }
      let!(:org_yhz) { Veteran::Service::Organization.create!(poa: 'YHZ', name: 'YHZ', can_accept_digital_poa_requests: false) }
      let(:poa_codes) { 'SVS,YHZ' }

      it 'updates matching orgs and returns counts' do
        result = call_service

        expect(result).to eq(2)
        expect(org_svs.reload.can_accept_digital_poa_requests).to be(true)
        expect(org_yhz.reload.can_accept_digital_poa_requests).to be(true)
      end
    end

    context 'with array input' do
      let!(:org_svs) { Veteran::Service::Organization.create!(poa: 'SVS', name: 'SVS', can_accept_digital_poa_requests: false) }
      let!(:org_yhz) { Veteran::Service::Organization.create!(poa: 'YHZ', name: 'YHZ', can_accept_digital_poa_requests: false) }
      let(:poa_codes) { %w[SVS YHZ] }

      it 'accepts arrays and updates matching orgs' do
        result = call_service

        expect(result).to eq(2)
        expect(org_svs.reload.can_accept_digital_poa_requests).to be(true)
        expect(org_yhz.reload.can_accept_digital_poa_requests).to be(true)
      end
    end

    context 'normalization: whitespace and duplicates' do
      let!(:org_svs) { Veteran::Service::Organization.create!(poa: 'SVS', name: 'SVS', can_accept_digital_poa_requests: false) }
      let(:poa_codes) { ' SVS ,  SVS  , ' }

      it 'trims and de-dupes, updating only needed rows' do
        result = call_service

        expect(result).to eq(1)
        expect(org_svs.reload.can_accept_digital_poa_requests).to be(true)
      end
    end

    context 'when blank after normalization' do
      let(:poa_codes) { ' , , ' }

      it 'raises ArgumentError' do
        expect { call_service }.to raise_error(ArgumentError, /POA codes required/)
      end
    end

    context 'when no organizations match' do
      let!(:org_other) { Veteran::Service::Organization.create!(poa: 'OTH', name: 'OTHER', can_accept_digital_poa_requests: false) }
      let(:poa_codes) { 'NOPE' }

      it 'does not raise and does not update others; returns zero counts' do
        result = nil
        expect { result = call_service }.not_to raise_error

        expect(result).to eq(0)
        expect(org_other.reload.can_accept_digital_poa_requests).to be(false)
      end
    end

    context 'idempotency' do
      let!(:org) { Veteran::Service::Organization.create!(poa: 'SVS', name: 'SVS', can_accept_digital_poa_requests: false) }
      let(:poa_codes) { 'SVS' }

      it 'is safe to call twice; second call updates nothing' do
        first = call_service
        expect(first).to eq(1)
        expect(org.reload.can_accept_digital_poa_requests).to be(true)

        second = described_class.call(poa_codes:)
        expect(second).to eq(0)
        expect(org.reload.can_accept_digital_poa_requests).to be(true)
      end
    end
  end
end
