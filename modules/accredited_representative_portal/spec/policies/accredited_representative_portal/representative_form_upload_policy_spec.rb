# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe RepresentativeFormUploadPolicy, type: :policy do
    subject(:policy) { described_class.new(user, '123498767V234859') }

    let(:user) { create(:representative_user) }
    let(:power_of_attorney_holders) { [] }

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
      context 'when user has no POA holders' do
        it 'denies access' do
          expect(policy.submit?).to be false
        end
      end

      context 'when user has at least one POA holder but does not accept digital POAs' do
        let(:power_of_attorney_holders) do
          [PowerOfAttorneyHolder.new(type: 'veteran_service_organization', poa_code: '067',
                                     can_accept_digital_poa_requests: false)]
        end

        it 'denies access' do
          expect(policy.submit?).to be false
        end
      end

      context 'when user has at least one POA holder that accepts digital POAs' do
        let(:power_of_attorney_holders) do
          [PowerOfAttorneyHolder.new(type: 'veteran_service_organization', poa_code: '067',
                                     can_accept_digital_poa_requests: true)]
        end

        it 'allows access' do
          expect(policy.submit?).to be true
        end
      end
    end
  end
end
