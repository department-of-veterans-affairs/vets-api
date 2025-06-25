# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe RepresentativeFormUploadPolicy, type: :policy do
    subject(:policy) { described_class.new(user, claimant_representative) }

    let(:user) { create(:representative_user) }
    let(:power_of_attorney_holders) { [] }
    let(:claimant_representative) { nil }

    before do
      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('<TOKEN>')
      allow(user.user_account).to receive(:power_of_attorney_holders).and_return(power_of_attorney_holders)
    end

    around do |example|
      VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
        example.run
      end
    end

    describe '#submit?' do
      context 'when user has no common POA holder with claimant' do
        it 'denies access' do
          expect(policy.submit?).to be false
        end
      end

      context 'when user has one common POA holder with claimant' do
        let(:claimant_representative) do
          ClaimantRepresentative.new(
            claimant_id: nil,
            power_of_attorney_holder_type: nil,
            power_of_attorney_holder_poa_code: nil,
            accredited_individual_registration_number: nil
          )
        end

        it 'allows access' do
          expect(policy.submit?).to be true
        end
      end
    end

    shared_examples 'scanned/supporting upload policy checks' do |method|
      describe "##{method}" do
        context 'when user has no POA holders' do
          it 'denies access' do
            expect(policy.public_send("#{method}?")).to be false
          end
        end

        context 'when user has at least one POA holder' do
          let(:power_of_attorney_holders) do
            [PowerOfAttorneyHolder.new(type: 'veteran_service_organization', poa_code: '067',
                                       can_accept_digital_poa_requests: nil)]
          end

          it 'allows access' do
            expect(policy.public_send("#{method}?")).to be true
          end
        end
      end
    end

    include_examples 'scanned/supporting upload policy checks', 'upload_scanned_form'
    include_examples 'scanned/supporting upload policy checks', 'upload_supporting_documents'
  end
end
