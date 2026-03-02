# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal # rubocop:disable Metrics/ModuleLength
  RSpec.describe PowerOfAttorneyRequestPolicy, type: :policy do
    subject(:policy) { described_class.new(user, power_of_attorney_request) }

    let(:user) { create(:representative_user) }
    let(:power_of_attorney_request) { create(:power_of_attorney_request, poa_code: '123') }
    let(:power_of_attorney_holders) { [] }

    before do
      allow(Flipper).to receive(:enabled?)
        .with(:accredited_representative_portal_individual_accept, user)
        .and_return(false)

      allow_any_instance_of(PowerOfAttorneyHolderMemberships).to(
        receive(:power_of_attorney_holders).and_return(power_of_attorney_holders)
      )
    end

    describe '#index?' do
      context 'when user has no POA holders' do
        it 'denies access' do
          expect(policy.index?).to be false
        end
      end

      context 'when user has at least one POA holder but does not accept digital POAs' do
        let(:power_of_attorney_holders) do
          [
            PowerOfAttorneyHolder.new(
              type: 'veteran_service_organization', poa_code: '123',
              name: 'Org Name', can_accept_digital_poa_requests: false
            )
          ]
        end

        it 'denies access' do
          expect(policy.index?).to be false
        end
      end

      context 'when user has at least one POA holder that accepts digital POAs' do
        let(:power_of_attorney_holders) do
          [
            PowerOfAttorneyHolder.new(
              type: 'veteran_service_organization', poa_code: '123',
              name: 'Org Name', can_accept_digital_poa_requests: true
            )
          ]
        end

        it 'allows access' do
          expect(policy.index?).to be true
        end
      end
    end

    describe '#show? (individual accept flag ON)' do
      let(:power_of_attorney_holders) do
        [
          PowerOfAttorneyHolder.new(
            type: 'veteran_service_organization',
            poa_code: '123',
            name: 'Org Name',
            can_accept_digital_poa_requests: true
          )
        ]
      end

      let(:vso_org) { create(:veteran_organization, poa: '123') }
      let(:vs_rep) { create(:veteran_representative, representative_id: 'REG1') }

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_individual_accept, user)
          .and_return(true)

        allow(user).to receive(:registration_numbers).and_return(['REG1'])
      end

      it 'denies when no join table record exists' do
        expect(policy.show?).to be false
      end

      it "allows when join table acceptance_mode is 'any_request'" do
        create(
          :veteran_organization_representative,
          organization: vso_org,
          representative: vs_rep,
          acceptance_mode: 'any_request',
          deactivated_at: nil
        )

        expect(policy.show?).to be true
      end

      it "allows when join table acceptance_mode is 'self_only' and user matches the request rep" do
        create(
          :veteran_organization_representative,
          organization: vso_org,
          representative: vs_rep,
          acceptance_mode: 'self_only',
          deactivated_at: nil
        )

        allow(power_of_attorney_request).to receive(:accredited_individual_registration_number).and_return('REG1')

        expect(policy.show?).to be true
      end

      it "denies when join table acceptance_mode is 'self_only' and user does NOT match the request rep" do
        create(
          :veteran_organization_representative,
          organization: vso_org,
          representative: vs_rep,
          acceptance_mode: 'self_only',
          deactivated_at: nil
        )

        allow(power_of_attorney_request).to receive(:accredited_individual_registration_number).and_return('SOMEONE_ELSE')

        expect(policy.show?).to be false
      end

      it "denies when join table acceptance_mode is 'no_acceptance'" do
        create(
          :veteran_organization_representative,
          organization: vso_org,
          representative: vs_rep,
          acceptance_mode: 'no_acceptance',
          deactivated_at: nil
        )

        expect(policy.show?).to be false
      end

      it 'denies when join table record is deactivated' do
        create(
          :veteran_organization_representative,
          organization: vso_org,
          representative: vs_rep,
          acceptance_mode: 'any_request',
          deactivated_at: Time.zone.now
        )

        expect(policy.show?).to be false
      end
    end

    describe '#show? (individual accept flag OFF)' do
      context 'when the POA holder can accept digital POA requests' do
        let(:power_of_attorney_holders) do
          [
            PowerOfAttorneyHolder.new(
              type: 'veteran_service_organization',
              poa_code: '123',
              name: 'Org Name',
              can_accept_digital_poa_requests: true
            )
          ]
        end

        it 'allows showing via the legacy authorization path' do
          expect(policy.show?).to be true
        end
      end

      context 'when the POA holder does not accept digital POA requests' do
        let(:power_of_attorney_holders) do
          [
            PowerOfAttorneyHolder.new(
              type: 'veteran_service_organization',
              poa_code: '123',
              name: 'Org Name',
              can_accept_digital_poa_requests: false
            )
          ]
        end

        it 'disallows showing via the legacy authorization path' do
          expect(policy.show?).to be false
        end
      end

      context 'when the user has no POA holders' do
        it 'denies access' do
          expect(policy.show?).to be false
        end
      end
    end

    describe '#create_decision? (individual accept flag ON)' do
      let(:power_of_attorney_holders) do
        [
          PowerOfAttorneyHolder.new(
            type: 'veteran_service_organization',
            poa_code: '123',
            name: 'Org Name',
            can_accept_digital_poa_requests: true
          )
        ]
      end

      let(:vso_org) { create(:veteran_organization, poa: '123') }
      let(:vs_rep) { create(:veteran_representative, representative_id: 'REG1') }

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:accredited_representative_portal_individual_accept, user)
          .and_return(true)

        allow(user).to receive(:registration_numbers).and_return(['REG1'])
      end

      it "allows when join table acceptance_mode is 'any_request'" do
        create(
          :veteran_organization_representative,
          organization: vso_org,
          representative: vs_rep,
          acceptance_mode: 'any_request',
          deactivated_at: nil
        )

        expect(policy.create_decision?).to be true
      end

      it "allows when join table acceptance_mode is 'self_only' and the user matches the representative" do
        create(
          :veteran_organization_representative,
          organization: vso_org,
          representative: vs_rep,
          acceptance_mode: 'self_only',
          deactivated_at: nil
        )

        allow(power_of_attorney_request).to receive(:accredited_individual_registration_number).and_return('REG1')

        expect(policy.create_decision?).to be true
      end

      it "disallows when join table acceptance_mode is 'no_acceptance'" do
        create(
          :veteran_organization_representative,
          organization: vso_org,
          representative: vs_rep,
          acceptance_mode: 'no_acceptance',
          deactivated_at: nil
        )

        expect(policy.create_decision?).to be false
      end

      it 'disallows when join table record is deactivated' do
        create(
          :veteran_organization_representative,
          organization: vso_org,
          representative: vs_rep,
          acceptance_mode: 'any_request',
          deactivated_at: Time.zone.now
        )

        expect(policy.create_decision?).to be false
      end
    end

    describe '#create_decision? (individual accept flag OFF)' do
      context 'when the POA holder can accept digital POA requests' do
        let(:power_of_attorney_holders) do
          [
            PowerOfAttorneyHolder.new(
              type: 'veteran_service_organization',
              poa_code: '123',
              name: 'Org Name',
              can_accept_digital_poa_requests: true
            )
          ]
        end

        it 'allows creating a decision via the legacy authorization path' do
          expect(policy.create_decision?).to be true
        end
      end

      context 'when the POA holder does not accept digital POA requests' do
        let(:power_of_attorney_holders) do
          [
            PowerOfAttorneyHolder.new(
              type: 'veteran_service_organization',
              poa_code: '123',
              name: 'Org Name',
              can_accept_digital_poa_requests: false
            )
          ]
        end

        it 'disallows creating a decision via the legacy authorization path' do
          expect(policy.create_decision?).to be false
        end
      end
    end

    describe 'Scope' do
      subject(:resolved_scope) { described_class::Scope.new(user, scope).resolve }

      let(:scope) { PowerOfAttorneyRequest.all }

      let!(:matching_request) { create(:power_of_attorney_request, poa_code: '123') }
      let!(:non_matching_request) { create(:power_of_attorney_request, poa_code: '999') }

      context 'when user has no POA holders' do
        it 'returns an empty scope' do
          expect(resolved_scope).to be_empty
        end
      end

      context 'when user has matching POA holders but does not accept digital POAs' do
        let(:power_of_attorney_holders) do
          [
            PowerOfAttorneyHolder.new(
              type: 'veteran_service_organization', poa_code: '123',
              name: 'Org Name', can_accept_digital_poa_requests: false
            )
          ]
        end

        it 'returns an empty scope' do
          expect(resolved_scope).to be_empty
        end
      end

      context 'when user has matching POA holders that accept digital POAs' do
        let(:power_of_attorney_holders) do
          [
            PowerOfAttorneyHolder.new(
              type: 'veteran_service_organization', poa_code: '123',
              name: 'Org Name', can_accept_digital_poa_requests: true
            )
          ]
        end

        it 'returns only matching requests' do
          expect(resolved_scope).to contain_exactly(matching_request)
        end
      end
    end
  end
end
