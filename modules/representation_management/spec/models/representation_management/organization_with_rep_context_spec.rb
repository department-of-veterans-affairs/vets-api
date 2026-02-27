# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::OrganizationWithRepContext do
  let(:organization) { create(:organization, poa: 'ABC', can_accept_digital_poa_requests: true) }
  let(:representative) { create(:representative, representative_id: '12345') }

  subject { described_class.new(organization, representative: representative) }

  describe '#can_accept_digital_poa_requests' do
    context 'when the organization cannot accept digital POA requests' do
      let(:organization) { create(:organization, poa: 'ABC', can_accept_digital_poa_requests: false) }

      it 'returns false' do
        expect(subject.can_accept_digital_poa_requests).to be false
      end
    end

    context 'when the organization can accept digital POA requests' do
      context 'when no organization_representative record exists' do
        it 'returns false' do
          expect(subject.can_accept_digital_poa_requests).to be false
        end
      end

      context 'when the organization_representative has acceptance_mode any_request' do
        before do
          create(:veteran_organization_representative,
                 representative:,
                 organization:,
                 acceptance_mode: 'any_request')
        end

        it 'returns true' do
          expect(subject.can_accept_digital_poa_requests).to be true
        end
      end

      context 'when the organization_representative has acceptance_mode self_only' do
        before do
          create(:veteran_organization_representative,
                 representative:,
                 organization:,
                 acceptance_mode: 'self_only')
        end

        it 'returns true' do
          expect(subject.can_accept_digital_poa_requests).to be true
        end
      end

      context 'when the organization_representative has acceptance_mode no_acceptance' do
        before do
          create(:veteran_organization_representative,
                 representative:,
                 organization:,
                 acceptance_mode: 'no_acceptance')
        end

        it 'returns false' do
          expect(subject.can_accept_digital_poa_requests).to be false
        end
      end

      context 'when a different rep has an active any_request record for the same org' do
        before do
          other_rep = create(:representative, representative_id: '99999')
          create(:veteran_organization_representative,
                 representative: other_rep,
                 organization:,
                 acceptance_mode: 'any_request')
        end

        it 'returns false' do
          expect(subject.can_accept_digital_poa_requests).to be false
        end
      end

      context 'when the organization_representative is deactivated' do
        before do
          create(:veteran_organization_representative,
                 representative:,
                 organization:,
                 acceptance_mode: 'any_request',
                 deactivated_at: Time.current)
        end

        it 'returns false' do
          expect(subject.can_accept_digital_poa_requests).to be false
        end
      end
    end
  end

  it 'delegates other methods to the organization' do
    expect(subject.poa).to eq('ABC')
    expect(subject.name).to eq(organization.name)
  end
end
