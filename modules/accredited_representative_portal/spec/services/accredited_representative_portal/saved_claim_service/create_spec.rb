# frozen_string_literal: true

require 'rails_helper'
require AccreditedRepresentativePortal::Engine.root / 'spec/spec_helper'

RSpec.describe AccreditedRepresentativePortal::SavedClaimService::Create do
  subject(:perform) do
    described_class.perform(
      type: AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim,
      attachment_guids: attachments.map(&:guid), metadata:,
      claimant_representative:
    )
  end

  let(:claimant_representative) do
    AccreditedRepresentativePortal::ClaimantRepresentative.new(
      claimant_id: Faker::Internet.uuid,
      power_of_attorney_holder_type:
        AccreditedRepresentativePortal::PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION,
      power_of_attorney_holder_poa_code: Faker::Alphanumeric.alphanumeric(number: 3),
      accredited_individual_registration_number: Faker::Number.number(digits: 5).to_s
    )
  end

  describe 'with invalid metadata' do
    let(:metadata) { {} }
    let(:attachments) { [] }

    it 'raises a generic `Error`' do
      expect { perform }.to raise_error(
        described_class::Error
      )
    end
  end

  describe 'with valid metadata' do
    fixture_path =
      'form_data/saved_claim/benefits_intake/dependent_claimant.json'

    dependent_claimant_form =
      load_fixture(fixture_path) do |fixture|
        JSON.parse(fixture)
      end

    let(:metadata) { dependent_claimant_form }

    describe 'attachment composition' do
      let(:form_a) { create(:persistent_attachment_va_form) }
      let(:form_b) { create(:persistent_attachment_va_form) }
      let(:attachment_a) { create(:persistent_attachment_va_form_documentation) }
      let(:attachment_b) { create(:persistent_attachment_va_form_documentation) }

      let(:already_parented_attachment) do
        create(
          ##
          # But of one of the expected types.
          #
          :persistent_attachment_va_form_documentation,
          saved_claim: build(:burial_claim)
        )
      end

      let(:extraneous_type_attachment) do
        create(:persistent_attachment)
      end

      describe 'parenting' do
        context 'one already parented' do
          let(:attachments) { [form_a, already_parented_attachment] }

          it 'raises `WrongAttachmentsError`' do
            expect { perform }.to raise_error(
              described_class::WrongAttachmentsError
            )
          end
        end

        context 'none already parented' do
          let(:attachments) { [form_a] }

          it 'returns a saved claim, enqueues the submission job, claimant representative was associated' do
            claim = perform

            expect(claim).to be_a(
              AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
            )

            expect(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
              have_enqueued_sidekiq_job(claim.id)
            )

            claimant_representative_associated =
              AccreditedRepresentativePortal::SavedClaimClaimantRepresentative.exists?(
                **claimant_representative.to_h,
                saved_claim_id: claim.id,
                claimant_type: 'dependent'
              )

            expect(claimant_representative_associated).to(
              be(true)
            )
          end
        end
      end

      describe 'composition' do
        context 'with no main form' do
          let(:attachments) { [attachment_a, attachment_b] }

          it 'raises `WrongAttachmentsError`' do
            expect { perform }.to raise_error(
              described_class::WrongAttachmentsError
            )
          end
        end

        context 'with a main form' do
          let(:attachments) { [form_a, attachment_a, attachment_b] }

          it 'returns a saved claim, enqueues the submission job, claimant representative was associated' do
            claim = perform

            expect(claim).to be_a(
              AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
            )

            expect(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
              have_enqueued_sidekiq_job(claim.id)
            )

            claimant_representative_associated =
              AccreditedRepresentativePortal::SavedClaimClaimantRepresentative.exists?(
                **claimant_representative.to_h,
                saved_claim_id: claim.id,
                claimant_type: 'dependent'
              )

            expect(claimant_representative_associated).to(
              be(true)
            )
          end

          context 'with an extraneous attachment type' do
            let(:attachments) { [form_a, extraneous_type_attachment] }

            it 'raises `WrongAttachmentsError`' do
              expect { perform }.to raise_error(
                described_class::WrongAttachmentsError
              )
            end
          end
        end
      end
    end
  end
end
