# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PowerOfAttorneyRequestPolicy, type: :policy do
    subject(:policy) { described_class.new(user, power_of_attorney_request) }

    let(:user) { build(:representative_user, :with_power_of_attorney_holders, poa_holders: user_poa_holders) }
    let(:power_of_attorney_request) { build(:power_of_attorney_request, power_of_attorney_holder_poa_code: 'POA123') }

    before do
      allow(user).to receive(:power_of_attorney_holders).and_return(user_poa_holders)
    end

    shared_examples 'POA authorization' do |action, expected_result|
      if expected_result == :raises_error
        it 'raises Pundit::NotAuthorizedError when user has no POA codes' do
          expect { policy.public_send(action) }.to raise_error(Pundit::NotAuthorizedError)
        end
      else
        it "#{expected_result ? 'allows' : 'denies'} access" do
          expect(policy.public_send(action)).to eq(expected_result)
        end
      end
    end

    describe '#show?' do
      context 'when user has no POA codes' do
        let(:user_poa_holders) { [] }

        it_behaves_like 'POA authorization', :show?, :raises_error
      end

      context 'when user has mismatched POA codes' do
        let(:user_poa_holders) { [build(:power_of_attorney_holder, poa_code: 'POA124')] }

        it_behaves_like 'POA authorization', :show?, false
      end

      context 'when user has matching POA codes' do
        let(:user_poa_holders) { [build(:power_of_attorney_holder, poa_code: 'POA123')] }

        it_behaves_like 'POA authorization', :show?, true
      end
    end

    describe '#index?' do
      context 'when user has no POA codes' do
        let(:user_poa_holders) { [] }

        it_behaves_like 'POA authorization', :index?, :raises_error
      end

      context 'when user has mismatched POA codes' do
        let(:user_poa_holders) { [build(:power_of_attorney_holder, poa_code: 'POA124')] }

        it_behaves_like 'POA authorization', :index?, false
      end

      context 'when user has matching POA codes' do
        let(:user_poa_holders) { [build(:power_of_attorney_holder, poa_code: 'POA123')] }

        it_behaves_like 'POA authorization', :index?, true
      end
    end

    describe 'Scope' do
      subject(:resolved_scope) { described_class::Scope.new(user, scope).resolve }

      let(:scope) { AccreditedRepresentativePortal::PowerOfAttorneyRequest }

      let!(:matching_request) { create(:power_of_attorney_request, power_of_attorney_holder_poa_code: 'POA123') }
      let!(:non_matching_request) { create(:power_of_attorney_request, power_of_attorney_holder_poa_code: 'POA999') }

      before do
        allow(user).to receive(:power_of_attorney_holders).and_return(user_poa_holders)
      end

      context 'when user has no POA codes' do
        let(:user_poa_holders) { [] }

        it 'returns an empty scope' do
          expect(resolved_scope).to be_empty
        end
      end

      context 'when user has matching POA codes' do
        let(:user_poa_holders) { [build(:power_of_attorney_holder, poa_code: 'POA123')] }

        it 'returns only requests with matching POA codes' do
          expect(resolved_scope).to contain_exactly(matching_request)
        end
      end

      context 'when user has multiple POA codes' do
        let(:user_poa_holders) do
          [
            build(:power_of_attorney_holder, poa_code: 'POA123'),
            build(:power_of_attorney_holder, poa_code: 'POA999')
          ]
        end

        it 'returns all matching requests' do
          expect(resolved_scope).to contain_exactly(matching_request, non_matching_request)
        end
      end
    end
  end
end
