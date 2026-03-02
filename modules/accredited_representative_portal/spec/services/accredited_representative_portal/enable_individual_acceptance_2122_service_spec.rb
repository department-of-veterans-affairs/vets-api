# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::EnableIndividualAcceptance2122Service do
  describe '.call' do
    subject(:call_service) { described_class.call(poa_codes:) }

    context 'with comma-separated string' do
      let!(:org_svs) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: true, name: 'SVS') }
      let!(:org_yhz) { create(:veteran_organization, poa: 'YHZ', can_accept_digital_poa_requests: true, name: 'YHZ') }
      let(:poa_codes) { 'SVS,YHZ' }

      it 'does not change org flag and returns counts' do
        result = call_service

        expect(result).to eq(orgs_updated: 0, reps_updated: 0)
        expect(org_svs.reload.can_accept_digital_poa_requests).to be(true)
        expect(org_yhz.reload.can_accept_digital_poa_requests).to be(true)
      end
    end

    context 'with array input' do
      let!(:org_svs) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: true, name: 'SVS') }
      let!(:org_yhz) { create(:veteran_organization, poa: 'YHZ', can_accept_digital_poa_requests: true, name: 'YHZ') }
      let(:poa_codes) { %w[SVS YHZ] }

      it 'handles array input equivalently to comma-separated string' do
        result = call_service

        expect(result).to eq(orgs_updated: 0, reps_updated: 0)
        expect(org_svs.reload.can_accept_digital_poa_requests).to be(true)
        expect(org_yhz.reload.can_accept_digital_poa_requests).to be(true)
      end
    end

    context 'normalization: whitespace and duplicates' do
      let!(:org) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: true, name: 'SVS') }
      let(:poa_codes) { [' SVS', 'SVS ', '  SVS', 'SVS'] }

      let!(:active_needs_update) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'any_request',
          deactivated_at: nil
        )
      end

      let!(:active_already_self_only) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'self_only',
          deactivated_at: nil
        )
      end

      let!(:deactivated_should_not_change) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'any_request',
          deactivated_at: Time.zone.now
        )
      end

      it 'trims whitespace, deduplicates codes, and updates active joins once' do
        result = call_service

        expect(result).to eq(orgs_updated: 0, reps_updated: 1)
        expect(active_needs_update.reload.acceptance_mode).to eq('self_only')
        expect(active_already_self_only.reload.acceptance_mode).to eq('self_only')
        expect(deactivated_should_not_change.reload.acceptance_mode).to eq('any_request')
      end
    end

    context 'when blank after normalization' do
      let(:poa_codes) { ' , , ' }

      it 'raises ArgumentError' do
        expect { call_service }.to raise_error(ArgumentError, /POA codes required/)
      end
    end

    context 'when no organizations match' do
      let!(:org_other) do
        create(:veteran_organization, poa: 'OTH', can_accept_digital_poa_requests: true, name: 'OTHER')
      end
      let(:poa_codes) { 'NOPE' }

      it 'does not raise and returns zero counts' do
        result = nil
        expect { result = call_service }.not_to raise_error

        expect(result).to eq(orgs_updated: 0, reps_updated: 0)
        expect(org_other.reload.can_accept_digital_poa_requests).to be(true)
      end
    end

    context 'updates rep permissions for active joins only' do
      let!(:org) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: true, name: 'SVS') }
      let(:poa_codes) { 'SVS' }

      let!(:active_needs_update) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'any_request',
          deactivated_at: nil
        )
      end

      let!(:active_already_self_only) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'self_only',
          deactivated_at: nil
        )
      end

      let!(:deactivated_should_not_change) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'any_request',
          deactivated_at: Time.zone.now
        )
      end

      it 'sets acceptance_mode=self_only for active joins and returns accurate counts' do
        result = call_service

        expect(result).to eq(orgs_updated: 0, reps_updated: 1)

        expect(active_needs_update.reload.acceptance_mode).to eq('self_only')
        expect(active_already_self_only.reload.acceptance_mode).to eq('self_only')
        expect(deactivated_should_not_change.reload.acceptance_mode).to eq('any_request')
      end
    end

    context 'idempotency' do
      let!(:org) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: true, name: 'SVS') }
      let(:poa_codes) { 'SVS' }

      let!(:active_join) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'any_request',
          deactivated_at: nil
        )
      end

      it 'is safe to call twice; second call updates nothing' do
        first = call_service
        expect(first).to eq(orgs_updated: 0, reps_updated: 1)
        expect(org.reload.can_accept_digital_poa_requests).to be(true)
        expect(active_join.reload.acceptance_mode).to eq('self_only')

        second = described_class.call(poa_codes:)
        expect(second).to eq(orgs_updated: 0, reps_updated: 0)
        expect(org.reload.can_accept_digital_poa_requests).to be(true)
        expect(active_join.reload.acceptance_mode).to eq('self_only')
      end
    end
  end
end
