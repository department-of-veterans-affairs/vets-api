# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PowerOfAttorneyRequestPolicy, type: :policy do
    subject(:policy) { described_class.new(user, power_of_attorney_request) }

    let(:user) { create(:representative_user) }
    let(:power_of_attorney_request) { create(:power_of_attorney_request, poa_code: 'POA123') }
    let(:user_poa_codes) { [] }

    before do
      allow(user).to receive(:power_of_attorney_holders)
        .and_return(user_poa_codes.map { |code| build(:power_of_attorney_holder, poa_code: code) })
    end

    describe '#index?' do
      context 'when user has no POA codes' do
        it 'denies access' do
          expect(policy.index?).to be false
        end
      end

      context 'when user has at least one POA code' do
        let(:user_poa_codes) { ['POA123'] }

        it 'allows access' do
          expect(policy.index?).to be true
        end
      end
    end

    describe '#show?' do
      context 'when user has no matching POA code' do
        it 'denies access' do
          expect(policy.show?).to be false
        end
      end

      context 'when user has a matching POA code' do
        let(:user_poa_codes) { ['POA123'] }

        it 'allows access' do
          expect(policy.show?).to be true
        end
      end
    end

    describe '#create_decision?' do
      context 'when user has no matching POA code' do
        it 'denies access' do
          expect(policy.create_decision?).to be false
        end
      end

      context 'when user has a matching POA code' do
        let(:user_poa_codes) { ['POA123'] }

        it 'allows access' do
          expect(policy.create_decision?).to be true
        end
      end
    end

    describe 'Scope' do
      subject(:resolved_scope) { described_class::Scope.new(user, scope).resolve }

      let(:scope) { AccreditedRepresentativePortal::PowerOfAttorneyRequest }
      let!(:matching_request) { create(:power_of_attorney_request, poa_code: 'POA123') }
      let!(:non_matching_request) { create(:power_of_attorney_request, poa_code: 'POA999') }
      let(:user_poa_codes) { [] }

      context 'when user has no POA codes' do
        it 'returns an empty scope' do
          expect(resolved_scope).to be_empty
        end
      end

      context 'when user has matching POA codes' do
        let(:user_poa_codes) { ['POA123'] }

        it 'returns only requests with matching POA codes' do
          expect(resolved_scope).to contain_exactly(matching_request)
        end
      end

      context 'when user has multiple POA codes' do
        let(:user_poa_codes) { %w[POA123 POA999] }

        it 'returns all matching requests' do
          expect(resolved_scope).to contain_exactly(matching_request, non_matching_request)
        end
      end
    end
  end
end
