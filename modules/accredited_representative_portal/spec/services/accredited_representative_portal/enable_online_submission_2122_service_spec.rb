# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::EnableOnlineSubmission2122Service do
  describe '.call' do
    subject(:call_service) { described_class.call(poa_codes:) }

    context 'with comma-separated string' do
      let!(:org_svs) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: false, name: 'SVS') }
      let!(:org_yhz) { create(:veteran_organization, poa: 'YHZ', can_accept_digital_poa_requests: false, name: 'YHZ') }
      let(:poa_codes) { 'SVS,YHZ' }

      it 'updates matching orgs and returns counts' do
        result = call_service

        expect(result).to eq(orgs_updated: 2, reps_updated: 0)
        expect(org_svs.reload.can_accept_digital_poa_requests).to be(true)
        expect(org_yhz.reload.can_accept_digital_poa_requests).to be(true)
      end
    end

    context 'with array input' do
      let!(:org_svs) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: false, name: 'SVS') }
      let!(:org_yhz) { create(:veteran_organization, poa: 'YHZ', can_accept_digital_poa_requests: false, name: 'YHZ') }
      let(:poa_codes) { %w[SVS YHZ] }

      it 'accepts arrays and updates matching orgs' do
        result = call_service

        expect(result).to eq(orgs_updated: 2, reps_updated: 0)
        expect(org_svs.reload.can_accept_digital_poa_requests).to be(true)
        expect(org_yhz.reload.can_accept_digital_poa_requests).to be(true)
      end
    end

    context 'normalization: whitespace and duplicates' do
      let!(:org_svs) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: false, name: 'SVS') }
      let(:poa_codes) { ' SVS ,  SVS  , ' }

      it 'trims and de-dupes, updating only needed rows' do
        result = call_service

        expect(result).to eq(orgs_updated: 1, reps_updated: 0)
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
      let!(:org_other) do
        create(:veteran_organization, poa: 'OTH', can_accept_digital_poa_requests: false, name: 'OTHER')
      end
      let(:poa_codes) { 'NOPE' }

      it 'does not raise and does not update others; returns zero counts' do
        result = nil
        expect { result = call_service }.not_to raise_error

        expect(result).to eq(orgs_updated: 0, reps_updated: 0)
        expect(org_other.reload.can_accept_digital_poa_requests).to be(false)
      end
    end

    context 'updates rep permissions for active joins only' do
      let!(:org) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: false, name: 'SVS') }
      let(:poa_codes) { 'SVS' }

      let!(:active_needs_update) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'no_acceptance',
          deactivated_at: nil
        )
      end

      let!(:active_already_any_request) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'any_request',
          deactivated_at: nil
        )
      end

      let!(:deactivated_should_not_change) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'no_acceptance',
          deactivated_at: Time.zone.now
        )
      end

      it 'sets acceptance_mode=any_request for active joins and returns accurate counts' do
        result = call_service

        expect(result).to eq(orgs_updated: 1, reps_updated: 1)

        expect(active_needs_update.reload.acceptance_mode).to eq('any_request')
        expect(active_already_any_request.reload.acceptance_mode).to eq('any_request')
        expect(deactivated_should_not_change.reload.acceptance_mode).to eq('no_acceptance')
      end
    end

    context 'idempotency' do
      let!(:org) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: false, name: 'SVS') }
      let(:poa_codes) { 'SVS' }

      let!(:active_join) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'no_acceptance',
          deactivated_at: nil
        )
      end

      it 'is safe to call twice; second call updates nothing' do
        first = call_service
        expect(first).to eq(orgs_updated: 1, reps_updated: 1)
        expect(org.reload.can_accept_digital_poa_requests).to be(true)
        expect(active_join.reload.acceptance_mode).to eq('any_request')

        second = described_class.call(poa_codes:)
        expect(second).to eq(orgs_updated: 0, reps_updated: 0)
        expect(org.reload.can_accept_digital_poa_requests).to be(true)
        expect(active_join.reload.acceptance_mode).to eq('any_request')
      end
    end

    context 'when org update count mismatches expected (fail loudly + rollback)' do
      let!(:org) { create(:veteran_organization, poa: 'SVS', can_accept_digital_poa_requests: false, name: 'SVS') }
      let(:poa_codes) { 'SVS' }

      let!(:active_join) do
        create(
          :veteran_organization_representative,
          organization: org,
          acceptance_mode: 'no_acceptance',
          deactivated_at: nil
        )
      end

      it 'raises and rolls back so rep acceptance_mode is not changed' do
        error_class = AccreditedRepresentativePortal::Poa2122ServiceHelpers::MismatchError

        allow(described_class).to receive(:enable_online_submission!)
          .and_raise(error_class, 'mismatch')

        expect { call_service }.to raise_error(error_class, /mismatch/i)

        expect(org.reload.can_accept_digital_poa_requests).to be(false)
        expect(active_join.reload.acceptance_mode).to eq('no_acceptance')
      end
    end
  end
end
