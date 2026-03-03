# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe PowerOfAttorneyRequestDecisionPolicy, type: :policy do
    subject(:policy) { described_class.new(user, decision) }

    let(:user) { create(:representative_user) }
    let(:decision) { build(:power_of_attorney_request_decision) }

    describe '#create?' do
      it 'delegates to PowerOfAttorneyRequest policy create_decision?' do
        poa_policy = instance_double(
          AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy,
          create_decision?: true
        )

        expect(Pundit)
          .to receive(:policy)
          .with(user, AccreditedRepresentativePortal::PowerOfAttorneyRequest)
          .and_return(poa_policy)

        expect(policy.create?).to be(true)
      end

      it 'returns false when PowerOfAttorneyRequest policy denies create_decision?' do
        poa_policy = instance_double(
          AccreditedRepresentativePortal::PowerOfAttorneyRequestPolicy,
          create_decision?: false
        )

        allow(Pundit)
          .to receive(:policy)
          .with(user, AccreditedRepresentativePortal::PowerOfAttorneyRequest)
          .and_return(poa_policy)

        expect(policy.create?).to be(false)
      end
    end
  end
end
