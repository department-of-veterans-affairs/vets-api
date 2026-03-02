# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PowerOfAttorneyRequestDecisionPolicy, type: :policy do
    subject(:policy) { described_class.new(user, power_of_attorney_request) }

    let(:user) { create(:representative_user) }
    let(:power_of_attorney_request) { create(:power_of_attorney_request, poa_code: '123') }

    describe '#create?' do
      it 'delegates authorization to PowerOfAttorneyRequestPolicy#create_decision?' do
        delegated_policy = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy)

        expect(Pundit)
          .to receive(:policy)
          .with(user, power_of_attorney_request)
          .and_return(delegated_policy)

        expect(delegated_policy)
          .to receive(:create_decision?)
          .and_return(true)

        expect(policy.create?).to be true
      end

      it 'returns false when delegated policy returns false' do
        delegated_policy = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy)

        allow(Pundit)
          .to receive(:policy)
          .with(user, power_of_attorney_request)
          .and_return(delegated_policy)

        allow(delegated_policy)
          .to receive(:create_decision?)
          .and_return(false)

        expect(policy.create?).to be false
      end

      it 'passes through errors from the delegated policy (no rescue here)' do
        delegated_policy = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy)

        allow(Pundit)
          .to receive(:policy)
          .with(user, power_of_attorney_request)
          .and_return(delegated_policy)

        allow(delegated_policy)
          .to receive(:create_decision?)
          .and_raise(StandardError, 'boom')

        expect { policy.create? }.to raise_error(StandardError, 'boom')
      end
    end
  end
end
