# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PowerOfAttorneyRequestPolicy, type: :policy do
    subject(:policy) { described_class.new(user, power_of_attorney_request) }

    let(:user) { create(:representative_user) }
    let(:power_of_attorney_request) { create(:power_of_attorney_request, poa_code: 'POA123') }
    let(:power_of_attorney_holders) { [] }

    before do
      allow(user.user_account).to receive(:power_of_attorney_holders).and_return(power_of_attorney_holders)
    end

    describe '#index?' do
      context 'when user has no POA holders' do
        it 'denies access' do
          expect(policy.index?).to be false
        end
      end

      context 'when user has at least one POA holder but does not accept digital POAs' do
        let(:power_of_attorney_holders) do
          [PowerOfAttorneyHolder.new(type: 'veteran_service_organization', poa_code: 'POA123',
                                     can_accept_digital_poa_requests: false)]
        end

        it 'denies access' do
          expect(policy.index?).to be false
        end
      end

      context 'when user has at least one POA holder that accepts digital POAs' do
        let(:power_of_attorney_holders) do
          [PowerOfAttorneyHolder.new(type: 'veteran_service_organization', poa_code: 'POA123',
                                     can_accept_digital_poa_requests: true)]
        end

        it 'allows access' do
          expect(policy.index?).to be true
        end
      end
    end

    describe '#show?' do
      context 'when user has no matching POA holder' do
        it 'denies access' do
          expect(policy.show?).to be false
        end
      end

      context 'when user has a matching POA code but does not accept digital POAs' do
        let(:power_of_attorney_holders) do
          [PowerOfAttorneyHolder.new(type: 'veteran_service_organization', poa_code: 'POA123',
                                     can_accept_digital_poa_requests: false)]
        end

        it 'denies access' do
          expect(policy.show?).to be false
        end
      end

      context 'when user has a matching POA code and accepts digital POAs' do
        let(:power_of_attorney_holders) do
          [PowerOfAttorneyHolder.new(type: 'veteran_service_organization', poa_code: 'POA123',
                                     can_accept_digital_poa_requests: true)]
        end

        it 'allows access' do
          expect(policy.show?).to be true
        end
      end
    end

    describe 'Scope' do
      subject(:resolved_scope) { described_class::Scope.new(user, scope).resolve }

      let(:scope) { PowerOfAttorneyRequest.all }

      let!(:matching_request) do
        create(:power_of_attorney_request, poa_code: 'POA123')
      end

      let!(:non_matching_request) do
        create(:power_of_attorney_request, poa_code: 'POA999')
      end

      let(:power_of_attorney_holders) { [] }

      context 'when user has no POA holders' do
        it 'returns an empty scope' do
          expect(resolved_scope).to be_empty
        end
      end

      context 'when user has matching POA holders but does not accept digital POAs' do
        let(:power_of_attorney_holders) do
          [PowerOfAttorneyHolder.new(type: 'veteran_service_organization', poa_code: 'POA123',
                                     can_accept_digital_poa_requests: false)]
        end

        it 'returns an empty scope' do
          expect(resolved_scope).to be_empty
        end
      end

      context 'when user has matching POA holders that accept digital POAs' do
        let(:power_of_attorney_holders) do
          [PowerOfAttorneyHolder.new(type: 'veteran_service_organization', poa_code: 'POA123',
                                     can_accept_digital_poa_requests: true)]
        end

        it 'returns only matching requests' do
          expect(resolved_scope).to contain_exactly(matching_request)
        end
      end
    end
  end
end
