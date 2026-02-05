# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe SavedClaimClaimantRepresentativePolicy, type: :policy do
    subject(:policy) { described_class.new(user, record_class) }

    let(:user)         { create(:representative_user) }
    let(:record_class) { AccreditedRepresentativePortal::SavedClaimClaimantRepresentative }

    let(:power_of_attorney_holders) { [] }
    let(:registration_numbers) { [] }

    before do
      allow_any_instance_of(PowerOfAttorneyHolderMemberships).to(
        receive_messages(
          power_of_attorney_holders:, registration_numbers:,
          empty?: power_of_attorney_holders.empty?
        )
      )

      # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
      # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
      allow(FastImage).to receive(:size).and_wrap_original do |original, file|
        if file.respond_to?(:path) && file.path.end_with?('.pdf')
          nil
        else
          original.call(file)
        end
      end
    end

    describe '#index?' do
      context 'when user has no POA holders' do
        it 'denies access' do
          expect(policy.index?).to be false
        end
      end

      context 'when user has at least one POA holder' do
        let(:power_of_attorney_holders) { [build(:power_of_attorney_holder, type: 'veteran_service_organization')] }

        it 'allows access' do
          expect(policy.index?).to be true
        end
      end
    end

    describe 'Scope' do
      subject(:resolved_scope) { described_class::Scope.new(user, scope).resolve }

      let(:scope) { AccreditedRepresentativePortal::SavedClaimClaimantRepresentative }

      let!(:matching_saved_claim)    { create(:saved_claim_benefits_intake) }
      let!(:nonmatching_saved_claim) { create(:saved_claim_benefits_intake) }

      let!(:matching_rep) do
        create(:saved_claim_claimant_representative,
               saved_claim: matching_saved_claim,
               accredited_individual_registration_number: 'AIRN-MATCH')
      end

      let!(:nonmatching_rep) do
        create(:saved_claim_claimant_representative,
               saved_claim: nonmatching_saved_claim,
               accredited_individual_registration_number: 'AIRN-OTHER')
      end

      context 'when user has no POA holders' do
        it 'returns an empty scope (since holder scope will be empty)' do
          allow(scope).to receive(:for_power_of_attorney_holders).with([]).and_return(scope.none)
          expect(resolved_scope).to be_empty
        end
      end

      context 'when user has POA holders but no registrations' do
        let(:power_of_attorney_holders) { [build(:power_of_attorney_holder, type: 'veteran_service_organization')] }

        it 'returns an empty scope (AIRN list is empty)' do
          allow(scope)
            .to receive(:for_power_of_attorney_holders)
            .with(power_of_attorney_holders)
            .and_return(scope.all)

          expect(resolved_scope).to be_empty
        end
      end

      context 'when user has POA holders and a matching registration AIRN' do
        let(:power_of_attorney_holders) { [build(:power_of_attorney_holder, type: 'veteran_service_organization')] }

        let(:registration_numbers) { ['AIRN-MATCH'] }

        before do
          allow(scope)
            .to receive(:for_power_of_attorney_holders)
            .with(power_of_attorney_holders)
            .and_return(scope.where(id: [matching_rep.id, nonmatching_rep.id]))
        end

        it 'returns only records whose AIRN matches any of the user registrations' do
          expect(resolved_scope).to contain_exactly(matching_rep)
        end
      end

      context 'orphaned records exist' do
        let!(:orphaned_record) do
          create(:saved_claim_claimant_representative,
                 saved_claim: matching_saved_claim2,
                 accredited_individual_registration_number: 'AIRN-MATCH')
        end
        let!(:matching_saved_claim2) { create(:saved_claim_benefits_intake) }

        it 'does not return records without saved claim data' do
          # rubocop:disable Rails/SkipsModelValidations
          orphaned_record.update_columns(saved_claim_id: 2489)
          # rubocop:enable Rails/SkipsModelValidations
          expect(resolved_scope).not_to include(orphaned_record)
        end
      end
    end
  end
end
