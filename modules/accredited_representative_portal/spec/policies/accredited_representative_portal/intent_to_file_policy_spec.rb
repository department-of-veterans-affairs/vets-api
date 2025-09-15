# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe IntentToFilePolicy, type: :policy do
    subject(:policy) { described_class.new(user, '123498767V234859') }

    let(:user) { create(:representative_user) }
    let(:power_of_attorney_holder_memberships) { [] }

    before do
      allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('<TOKEN>')
      allow_any_instance_of(PowerOfAttorneyHolderMemberships).to(
        receive(:all).and_return(power_of_attorney_holder_memberships)
      )
    end

    around do |example|
      VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
        example.run
      end
    end

    describe '#show?' do
      context 'when user has no POA holders' do
        it 'denies access' do
          expect(policy.show?).to be false
        end
      end

      context 'when user has at least one POA holder' do
        let(:power_of_attorney_holder_memberships) do
          [
            PowerOfAttorneyHolderMemberships::Membership.new(
              registration_number: '1234',
              power_of_attorney_holder:
                PowerOfAttorneyHolder.new(
                  type: 'veteran_service_organization', poa_code: '067',
                  name: 'Org Name', can_accept_digital_poa_requests: nil
                )
            )
          ]
        end

        it 'allows access' do
          expect(policy.show?).to be true
        end
      end
    end
  end
end
