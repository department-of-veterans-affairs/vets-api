# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::ClaimantRepresentative, type: :model do
  describe '.find' do
    context 'without all required arguments' do
      subject do
        described_class.find {}
      end

      it 'raises Finder::Error' do
        expect { subject }.to raise_error(
          described_class::Finder::Error
        )
      end
    end

    context 'with all required arguments' do
      subject do
        described_class.find do |finder|
          finder.for_claimant(
            icn: claimant_icn
          )

          finder.for_representative(
            icn: representative_icn,
            email: representative_email,
            all_emails: [representative_email]
          )
        end
      end

      context 'with a representative belonging to 2 VSOs' do
        before do
          vso_a = create(:organization, poa: poa_code_a)
          vso_b = create(:organization, poa: poa_code_b)

          representative =
            create(
              :representative, :vso,
              poa_codes: [vso_a.poa, vso_b.poa],
              email: representative_email
            )

          create(
            :user_account_accredited_individual,
            user_account_email: representative_email,
            user_account_icn: representative_icn,
            accredited_individual_registration_number:
              representative.representative_id
          )

          create(
            :user_account,
            icn: representative_icn
          )
        end

        let(:poa_code_a) { '00A' }
        let(:poa_code_b) { '00B' }
        let(:representative_icn) { Faker::Number.unique.number(digits: 10) }
        let(:representative_email) { Faker::Internet.email }
        let(:claimant_icn) { Faker::Number.unique.number(digits: 10) }

        context '`BenefitsClaims::Service` does raise' do
          before do
            allow_any_instance_of(BenefitsClaims::Service).to(
              receive(:get_power_of_attorney).and_raise(
                Common::Exceptions::ResourceNotFound
              )
            )
          end

          it 'raises Finder::Error' do
            expect { subject }.to raise_error(
              described_class::Finder::Error
            )
          end
        end

        context '`BenefitsClaims::Service` does not raise' do
          context 'and does not return poa data' do
            before do
              allow_any_instance_of(BenefitsClaims::Service).to(
                receive(:get_power_of_attorney).and_return(
                  { 'data' => {} }
                )
              )
            end

            it 'returns nil' do
              expect(subject).to be_nil
            end
          end

          context 'and returns some poa data' do
            before do
              allow_any_instance_of(BenefitsClaims::Service).to(
                receive(:get_power_of_attorney).and_return(
                  {
                    'data' => {
                      'type' => 'organization',
                      'attributes' => {
                        'code' => claimant_poa_code
                      }
                    }
                  }
                )
              )
            end

            context 'and a claimant that has poa with one of them' do
              let(:claimant_poa_code) { poa_code_a }

              it 'returns a `ClaimantRepresentative`' do
                expect(subject).to have_attributes(
                  claimant_id: be_a(String),
                  accredited_individual_registration_number: be_a(String),
                  power_of_attorney_holder_poa_code: claimant_poa_code,
                  power_of_attorney_holder_type:
                    AccreditedRepresentativePortal::PowerOfAttorneyHolder::Types::
                      VETERAN_SERVICE_ORGANIZATION
                )
              end
            end

            context 'and a claimant that does not have poa with one of them' do
              let(:claimant_poa_code) { 'XYZ' }

              it 'returns nil' do
                expect(subject).to be_nil
              end
            end
          end
        end
      end
    end
  end
end
