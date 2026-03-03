# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal # rubocop:disable Metrics/ModuleLength
  RSpec.describe PowerOfAttorneyRequestPolicy, type: :policy do
    subject(:policy) { described_class.new(user, power_of_attorney_request) }

    let(:user) { create(:representative_user) }

    let(:power_of_attorney_request) { create(:power_of_attorney_request, poa_code:) }
    let(:poa_code) { '123' }

    let(:power_of_attorney_holders) { [] }
    let(:registration_numbers) { [] }

    before do
      allow_any_instance_of(PowerOfAttorneyHolderMemberships).to(
        receive(:power_of_attorney_holders).and_return(power_of_attorney_holders)
      )
      allow_any_instance_of(PowerOfAttorneyHolderMemberships).to(
        receive(:registration_numbers).and_return(registration_numbers)
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
              type: 'veteran_service_organization',
              poa_code:,
              name: 'Org Name',
              can_accept_digital_poa_requests: false
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
              type: 'veteran_service_organization',
              poa_code:,
              name: 'Org Name',
              can_accept_digital_poa_requests: true
            )
          ]
        end

        it 'allows access' do
          expect(policy.index?).to be true
        end
      end
    end

    describe '#show?' do
      context 'when feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:accredited_representative_portal_individual_accept, user)
            .and_return(false)
        end

        context 'when user has no matching POA holder' do
          it 'denies access' do
            expect(policy.show?).to be false
          end
        end

        context 'when user has a matching POA code but does not accept digital POAs' do
          let(:power_of_attorney_holders) do
            [
              PowerOfAttorneyHolder.new(
                type: 'veteran_service_organization',
                poa_code:,
                name: 'Org Name',
                can_accept_digital_poa_requests: false
              )
            ]
          end

          it 'denies access' do
            expect(policy.show?).to be false
          end
        end

        context 'when user has a matching POA code and accepts digital POAs' do
          let(:power_of_attorney_holders) do
            [
              PowerOfAttorneyHolder.new(
                type: 'veteran_service_organization',
                poa_code:,
                name: 'Org Name',
                can_accept_digital_poa_requests: true
              )
            ]
          end

          it 'allows access' do
            expect(policy.show?).to be true
          end
        end
      end

      context 'when feature flag is enabled' do
        let(:vso_org) { create(:veteran_organization, poa: poa_code) }
        let(:vso_rep) { create(:veteran_representative) }

        before do
          allow(Flipper).to receive(:enabled?)
            .with(:accredited_representative_portal_individual_accept, user)
            .and_return(true)

          allow(user).to receive(:registration_numbers).and_return([vso_rep.representative_id])
        end

        context 'when user is not in a participating org for this request' do
          let(:power_of_attorney_holders) do
            [
              PowerOfAttorneyHolder.new(
                type: 'veteran_service_organization',
                poa_code:,
                name: 'Org Name',
                can_accept_digital_poa_requests: false
              )
            ]
          end

          it 'denies access even if org rep row exists' do
            create(
              :veteran_organization_representative,
              organization: vso_org,
              representative: vso_rep,
              acceptance_mode: 'any_request'
            )

            expect(policy.show?).to be false
          end
        end

        context 'when acceptance_mode is no_acceptance' do
          let(:power_of_attorney_holders) do
            [
              PowerOfAttorneyHolder.new(
                type: 'veteran_service_organization',
                poa_code:,
                name: 'Org Name',
                can_accept_digital_poa_requests: true
              )
            ]
          end

          it 'denies access' do
            create(
              :veteran_organization_representative,
              organization: vso_org,
              representative: vso_rep,
              acceptance_mode: 'no_acceptance'
            )

            expect(policy.show?).to be false
          end
        end

        context 'when acceptance_mode is any_request' do
          let(:power_of_attorney_holders) do
            [
              PowerOfAttorneyHolder.new(
                type: 'veteran_service_organization',
                poa_code:,
                name: 'Org Name',
                can_accept_digital_poa_requests: true
              )
            ]
          end

          it 'allows access' do
            create(
              :veteran_organization_representative,
              organization: vso_org,
              representative: vso_rep,
              acceptance_mode: 'any_request'
            )

            expect(policy.show?).to be true
          end
        end

        context 'when acceptance_mode is self_only' do
          let(:power_of_attorney_holders) do
            [
              PowerOfAttorneyHolder.new(
                type: 'veteran_service_organization',
                poa_code:,
                name: 'Org Name',
                can_accept_digital_poa_requests: true
              )
            ]
          end

          before do
            create(
              :veteran_organization_representative,
              organization: vso_org,
              representative: vso_rep,
              acceptance_mode: 'self_only'
            )
          end

          context 'when request is for this representative' do
            let(:power_of_attorney_request) do
              create(:power_of_attorney_request, poa_code:).tap do |req|
                req.update!(accredited_individual_registration_number: vso_rep.representative_id)
              end
            end

            it 'allows access' do
              expect(policy.show?).to be true
            end
          end

          context 'when request is NOT for this representative' do
            let(:power_of_attorney_request) do
              create(:power_of_attorney_request, poa_code:).tap do |req|
                req.update!(accredited_individual_registration_number: '999999')
              end
            end

            it 'denies access' do
              expect(policy.show?).to be false
            end
          end
        end

        context 'when acceptance_mode is unexpected' do
          let(:power_of_attorney_holders) do
            [
              PowerOfAttorneyHolder.new(
                type: 'veteran_service_organization',
                poa_code:,
                name: 'Org Name',
                can_accept_digital_poa_requests: true
              )
            ]
          end

          it 'denies access' do
            create(
              :veteran_organization_representative,
              organization: vso_org,
              representative: vso_rep,
              acceptance_mode: 'any_request'
            )

            allow_any_instance_of(Veteran::Service::OrganizationRepresentative)
              .to receive(:acceptance_mode)
              .and_return('unexpected_value')

            expect(policy.show?).to be false
          end
        end
      end
    end

    describe '#create_decision?' do
      it 'matches show? behavior' do
        expect(policy.create_decision?).to eq(policy.show?)
      end
    end

    describe 'Scope' do
      subject(:resolved_scope) { described_class::Scope.new(user, scope).resolve }

      let(:scope) { PowerOfAttorneyRequest.all }

      let!(:matching_request) { create(:power_of_attorney_request, poa_code:) }
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
              type: 'veteran_service_organization',
              poa_code:,
              name: 'Org Name',
              can_accept_digital_poa_requests: false
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
              type: 'veteran_service_organization',
              poa_code:,
              name: 'Org Name',
              can_accept_digital_poa_requests: true
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
