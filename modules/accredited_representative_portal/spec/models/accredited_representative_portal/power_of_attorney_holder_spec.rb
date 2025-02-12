# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PowerOfAttorneyHolder, type: :model do
    let(:user_email) { 'rep1@vso.org' }
    let(:user_icn) { 'ICN001' }
    let(:poa_code) { 'POA123' }

    let!(:user_account) do
      UserAccountAccreditedIndividual.create!(
        accredited_individual_registration_number: 'REG001',
        power_of_attorney_holder_type: described_class::Types::VETERAN_SERVICE_ORGANIZATION,
        user_account_email: user_email,
        user_account_icn: user_icn
      )
    end

    let!(:poa_organization) do
      instance_double(Veteran::Service::Organization, poa: poa_code, can_accept_digital_poa_requests: true)
    end

    let!(:representative) do
      instance_double(Veteran::Service::Representative, poa_codes: [poa_code])
    end

    before do
      allow(Veteran::Service::Organization).to receive(:find_by).with(poa: [poa_code])
                                                                .and_return([poa_organization])
      allow(Veteran::Service::Representative).to receive(:find_by).with(representative_id: 'REG001')
                                                                  .and_return(representative)
    end

    describe '.for_user' do
      context 'when a matching user is found' do
        it 'returns an array of PowerOfAttorneyHolder instances' do
          poa_holders = described_class.for_user(email: user_email, icn: user_icn)

          expect(poa_holders).not_to be_empty
          expect(poa_holders.first).to be_a(described_class)
          expect(poa_holders.first.type).to eq(described_class::Types::VETERAN_SERVICE_ORGANIZATION)
          expect(poa_holders.first.poa_code).to eq(poa_code)
          expect(poa_holders.first.can_accept_digital_poa_requests).to be true
        end
      end

      context 'when no matching user is found' do
        it 'returns an empty array' do
          allow(UserAccountAccreditedIndividual).to receive(:reconcile_and_find_by)
            .with(user_account_email: 'nonexistent@vso.org', user_account_icn: 'ICN999')
            .and_return([])

          result = described_class.for_user(email: 'nonexistent@vso.org', icn: 'ICN999')
          expect(result).to eq([])
        end
      end

      context 'when user exists but has no associated POA organizations' do
        it 'returns an empty array' do
          allow(Veteran::Service::Organization).to receive(:find_by).and_return([])

          poa_holders = described_class.for_user(email: user_email, icn: user_icn)
          expect(poa_holders).to be_empty
        end
      end
    end

    describe '#accepts_digital_power_of_attorney_requests?' do
      it 'returns the value of can_accept_digital_poa_requests' do
        poa_holder = described_class.new(
          type: described_class::Types::VETERAN_SERVICE_ORGANIZATION,
          poa_code: poa_code,
          can_accept_digital_poa_requests: true
        )

        expect(poa_holder.accepts_digital_power_of_attorney_requests?).to be true
      end
    end
  end
end
