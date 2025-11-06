# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal # rubocop:disable Metrics/ModuleLength
  RSpec.describe PowerOfAttorneyHolderMemberships do
    describe '#all' do
      subject(:all) { described_class.new(icn: 'some_icn', emails:).send(:all) }

      let(:emails) { [] }

      before do
        numbers = upstream_registrations.map(&:representative_id)
        expect_any_instance_of(OgcClient).to(
          receive(:find_registration_numbers_for_icn)
          .and_return(numbers)
        )
      end

      describe 'OGC returns registrations with duplicated type' do
        let(:upstream_registrations) do
          [
            create(
              :representative,
              user_types: ['attorney'],
              representative_id: 'R1000'
            ),
            create(
              :representative,
              user_types: ['attorney'],
              representative_id: 'R1001'
            )
          ]
        end

        it 'raises `Common::Exceptions::Forbidden`' do
          expect { all }.to raise_error(Common::Exceptions::Forbidden)
        end
      end

      describe 'OGC returns valid registrations' do
        let(:upstream_registrations) do
          [
            create(
              :representative,
              user_types: ['attorney'],
              representative_id: 'R1000',
              poa_codes: ['P10']
            ),
            create(
              :representative,
              user_types: ['claim_agents'],
              representative_id: 'R1001',
              poa_codes: ['P11']
            )
          ]
        end

        it 'returns memberships' do
          expect(all).to eq(
            [
              described_class::Membership.new(
                registration_number: 'R1000',
                power_of_attorney_holder:
                  PowerOfAttorneyHolder.new(
                    type: 'attorney',
                    name: 'Bob Law',
                    poa_code: 'P10',
                    can_accept_digital_poa_requests: false
                  )
              ),
              described_class::Membership.new(
                registration_number: 'R1001',
                power_of_attorney_holder:
                  PowerOfAttorneyHolder.new(
                    type: 'claims_agent',
                    name: 'Bob Law',
                    poa_code: 'P11',
                    can_accept_digital_poa_requests: false
                  )
              )
            ]
          )
        end
      end

      describe 'OGC returns no registrations' do
        let(:upstream_registrations) { [] }

        describe 'DB returns no registrations' do
          let(:emails) do
            [
              'nonexistent1@example.com',
              'nonexistent2@example.com'
            ]
          end

          it 'raises `Common::Exceptions::Forbidden`' do
            expect { all }.to raise_error(Common::Exceptions::Forbidden)
          end
        end

        describe 'provided emails match registrations with duplicated types' do
          let(:emails) do
            [
              'matching1@example.com',
              'matching2@example.com'
            ]
          end

          before do
            create(
              :representative,
              user_types: ['attorney'],
              representative_id: 'R1000',
              email: emails.first
            )
            create(
              :representative,
              user_types: ['attorney'],
              representative_id: 'R1001',
              email: emails.last
            )
          end

          it 'raises `Common::Exceptions::Forbidden`' do
            expect { all }.to raise_error(Common::Exceptions::Forbidden)
          end
        end

        describe 'provided emails match valid registration set' do
          let(:emails) do
            [
              'matching1@example.com',
              'matching2@example.com'
            ]
          end

          before do
            create(
              :representative,
              user_types: ['attorney'],
              representative_id: 'R1000',
              poa_codes: ['P10'],
              email: emails.first
            )
            create(
              :representative,
              user_types: ['claim_agents'],
              representative_id: 'R1001',
              poa_codes: ['P11'],
              email: emails.last
            )
            create(
              :representative,
              user_types: ['veteran_service_officer'],
              representative_id: 'R1002',
              poa_codes: %w[P12 P13],
              email: emails.last
            )

            create(:organization, poa: 'P12', name: 'Org A')
            create(:organization, poa: 'P13', name: 'Org B', can_accept_digital_poa_requests: true)

            expect_any_instance_of(OgcClient).to(
              receive(:post_icn_and_registration_combination)
              .at_least(:once)
              .and_return(put_upstream_registration_result)
            )
          end

          describe 'and write to OGC is not a conflict' do
            let(:put_upstream_registration_result) { true }

            it 'returns memberships' do
              expect(all).to eq(
                [
                  described_class::Membership.new(
                    registration_number: 'R1000',
                    power_of_attorney_holder:
                      PowerOfAttorneyHolder.new(
                        type: 'attorney',
                        name: 'Bob Law',
                        poa_code: 'P10',
                        can_accept_digital_poa_requests: false
                      )
                  ),
                  described_class::Membership.new(
                    registration_number: 'R1001',
                    power_of_attorney_holder:
                      PowerOfAttorneyHolder.new(
                        type: 'claims_agent',
                        name: 'Bob Law',
                        poa_code: 'P11',
                        can_accept_digital_poa_requests: false
                      )
                  ),
                  described_class::Membership.new(
                    registration_number: 'R1002',
                    power_of_attorney_holder:
                      PowerOfAttorneyHolder.new(
                        type: 'veteran_service_organization',
                        name: 'Org A',
                        poa_code: 'P12',
                        can_accept_digital_poa_requests: false
                      )
                  ),
                  described_class::Membership.new(
                    registration_number: 'R1002',
                    power_of_attorney_holder:
                      PowerOfAttorneyHolder.new(
                        type: 'veteran_service_organization',
                        name: 'Org B',
                        poa_code: 'P13',
                        can_accept_digital_poa_requests: true
                      )
                  )
                ]
              )
            end
          end

          describe 'and write to OGC is a conflict' do
            let(:put_upstream_registration_result) { :conflict }

            it 'raises `Common::Exceptions::Forbidden`' do
              expect { all }.to raise_error(Common::Exceptions::Forbidden)
            end
          end
        end
      end
    end

    context 'given a full setup' do
      let(:put_upstream_registration_result) { true }
      let(:upstream_registrations) { [] }

      let(:emails) do
        [
          'matching1@example.com',
          'matching2@example.com'
        ]
      end

      before do
        create(
          :representative,
          user_types: ['attorney'],
          representative_id: 'R1000',
          poa_codes: ['P10'],
          email: emails.first
        )
        create(
          :representative,
          user_types: ['claim_agents'],
          representative_id: 'R1001',
          poa_codes: ['P11'],
          email: emails.last
        )
        create(
          :representative,
          user_types: ['veteran_service_officer'],
          representative_id: 'R1002',
          poa_codes: %w[P12 P13],
          email: emails.last
        )

        create(:organization, poa: 'P12', name: 'Org A')
        create(:organization, poa: 'P13', name: 'Org B', can_accept_digital_poa_requests: true)

        expect_any_instance_of(OgcClient).to(
          receive(:post_icn_and_registration_combination)
          .at_least(:once)
          .and_return(put_upstream_registration_result)
        )

        numbers = upstream_registrations.map(&:representative_id)
        expect_any_instance_of(OgcClient).to(
          receive(:find_registration_numbers_for_icn)
          .and_return(numbers)
        )
      end

      describe '#registration_numbers' do
        subject(:registration_numbers) do
          memberships = described_class.new(icn: 'some_icn', emails:)
          memberships.registration_numbers
        end

        it 'returns registration_numbers' do
          expect(registration_numbers).to eq(%w[R1000 R1001 R1002])
        end
      end

      describe '#power_of_attorney_holders' do
        subject(:power_of_attorney_holders) do
          memberships = described_class.new(icn: 'some_icn', emails:)
          memberships.power_of_attorney_holders
        end

        it 'returns power_of_attorney_holders' do
          expect(power_of_attorney_holders).to eq(
            [
              PowerOfAttorneyHolder.new(
                type: 'attorney',
                name: 'Bob Law',
                poa_code: 'P10',
                can_accept_digital_poa_requests: false
              ),
              PowerOfAttorneyHolder.new(
                type: 'claims_agent',
                name: 'Bob Law',
                poa_code: 'P11',
                can_accept_digital_poa_requests: false
              ),
              PowerOfAttorneyHolder.new(
                type: 'veteran_service_organization',
                name: 'Org A',
                poa_code: 'P12',
                can_accept_digital_poa_requests: false
              ),
              PowerOfAttorneyHolder.new(
                type: 'veteran_service_organization',
                name: 'Org B',
                poa_code: 'P13',
                can_accept_digital_poa_requests: true
              )
            ]
          )
        end
      end

      describe '#find' do
        subject(:find) do
          memberships = described_class.new(icn: 'some_icn', emails:)
          memberships.find('P13')
        end

        it 'finds the membership that matches the provided poa holder' do
          expect(find).to eq(
            described_class::Membership.new(
              registration_number: 'R1002',
              power_of_attorney_holder:
                PowerOfAttorneyHolder.new(
                  poa_code: 'P13',
                  type: 'veteran_service_organization',
                  name: 'Org B',
                  can_accept_digital_poa_requests: true
                )
            )
          )
        end
      end
    end
  end
end
