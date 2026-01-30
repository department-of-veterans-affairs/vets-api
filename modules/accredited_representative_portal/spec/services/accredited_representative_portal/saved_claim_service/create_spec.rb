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

  before do
    allow_any_instance_of(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
      receive(:perform)
    )

    # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
    # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
    allow(FastImage).to receive(:size).and_wrap_original do |original, file|
      if file.respond_to?(:path) && file.path.end_with?('.pdf')
        nil
      else
        original.call(file)
      end
    end
  end

  let(:claimant_representative) do
    AccreditedRepresentativePortal::ClaimantRepresentative.new(
      claimant_id: Faker::Internet.uuid,
      accredited_individual_registration_number: Faker::Number.number(digits: 5).to_s,
      power_of_attorney_holder:
        AccreditedRepresentativePortal::PowerOfAttorneyHolder.new(
          type: AccreditedRepresentativePortal::PowerOfAttorneyHolder::Types::VETERAN_SERVICE_ORGANIZATION,
          name: 'Org Name',
          poa_code: Faker::Alphanumeric.alphanumeric(number: 3),
          can_accept_digital_poa_requests: nil
        )
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
      let(:form_a) { create(:persistent_attachment_va_form, form_id: '21-686c') }
      let(:form_b) { create(:persistent_attachment_va_form, form_id: '21-686c') }
      let(:attachment_a) { create(:persistent_attachment_va_form_documentation, form_id: '21-686c') }
      let(:attachment_b) { create(:persistent_attachment_va_form_documentation, form_id: '21-686c') }

      let(:already_parented_attachment) do
        create(
          ##
          # But of one of the expected types.
          #
          :persistent_attachment_va_form_documentation,
          saved_claim: build(:fake_saved_claim),
          form_id: '21-686c'
        )
      end

      let(:extraneous_type_attachment) do
        create(:persistent_attachment, form_id: '21-686c')
      end

      describe 'form type' do
        let(:extraneous_form_type_attachment) do
          create(:persistent_attachment_va_form, form_id: 'nonsense')
        end

        let(:attachments) { [extraneous_form_type_attachment] }

        it 'raises `WrongAttachmentsError`' do
          expect { perform }.to raise_error(
            described_class::WrongAttachmentsError
          )
        end
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
            expect_any_instance_of(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
              receive(:perform)
            )

            claim = perform

            expect(claim).to be_a(
              AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
            )

            claimant_representative_associated =
              AccreditedRepresentativePortal::SavedClaimClaimantRepresentative.exists?(
                claimant_id:
                  claimant_representative.claimant_id,
                accredited_individual_registration_number:
                  claimant_representative.accredited_individual_registration_number,
                power_of_attorney_holder_type:
                  claimant_representative.power_of_attorney_holder.type,
                power_of_attorney_holder_poa_code:
                  claimant_representative.power_of_attorney_holder.poa_code,
                saved_claim_id: claim.id,
                claimant_type: 'dependent'
              )

            expect(claimant_representative_associated).to(
              be(true)
            )
          end

          it 'persists the saved claim even when attachments are not persisted' do
            # Build (not create) attachments so association autosave won't persist the saved_claim
            form = build(:persistent_attachment_va_form, form_id: '21-686c')
            doc = build(:persistent_attachment_va_form_documentation, form_id: '21-686c')

            # Stub organize_attachments! to return our in-memory (non-persisted) attachments
            allow(described_class).to receive(:organize_attachments!).and_return({ form:, documentations: [doc] })

            created = nil
            # Stub create! and do NOT call through to prevent any DB side-effects
            allow(
              AccreditedRepresentativePortal::SavedClaimClaimantRepresentative
            ).to receive(:create!).and_wrap_original do |_m, *args|
              created = args.first
              # simulate create! returning a record without touching DB
              AccreditedRepresentativePortal::SavedClaimClaimantRepresentative.new(created)
            end

            claim = perform

            expect(created[:saved_claim].persisted?).to be(true)
            expect(created[:saved_claim].id).to eq(claim.id)
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
            expect_any_instance_of(AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob).to(
              receive(:perform)
            )

            claim = perform

            expect(claim).to be_a(
              AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
            )

            claimant_representative_associated =
              AccreditedRepresentativePortal::SavedClaimClaimantRepresentative.exists?(
                claimant_id:
                  claimant_representative.claimant_id,
                accredited_individual_registration_number:
                  claimant_representative.accredited_individual_registration_number,
                power_of_attorney_holder_type:
                  claimant_representative.power_of_attorney_holder.type,
                power_of_attorney_holder_poa_code:
                  claimant_representative.power_of_attorney_holder.poa_code,
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

          context 'with invalid parameters' do
            let(:attachments) { [form_a, attachment_a, attachment_b] }
            let(:claimant_representative) do
              AccreditedRepresentativePortal::ClaimantRepresentative.new(
                claimant_id: Faker::Internet.uuid,
                accredited_individual_registration_number: 'wrong',
                power_of_attorney_holder:
                  AccreditedRepresentativePortal::PowerOfAttorneyHolder.new(
                    type: 'invalid',
                    poa_code: 'super-invalid',
                    name: 'Org Name',
                    can_accept_digital_poa_requests: nil
                  )
              )
            end

            it 'raises RecordInvalidError' do
              expect { perform }.to raise_error described_class::RecordInvalidError
            end
          end

          context 'when Faraday raises TooManyRequestsError' do
            it 'raises TooManyRequestsError' do
              allow_any_instance_of(
                AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob
              ).to receive(:perform).and_raise(Faraday::TooManyRequestsError.new('Too Many Requests'))

              expect { perform }.to raise_error described_class::TooManyRequestsError
            end
          end

          context 'unhandled errors' do
            it 'raises UnknownError' do
              allow_any_instance_of(
                AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob
              ).to receive(:perform).and_raise(StandardError.new('kaboom'))

              expect { perform }.to raise_error described_class::UnknownError
            end
          end

          context 'with any error' do
            let(:attachments) { [form_a, attachment_a, attachment_b] }

            before do
              allow_any_instance_of(
                AccreditedRepresentativePortal::SubmitBenefitsIntakeClaimJob
              ).to receive(:perform).and_raise(described_class::WrongAttachmentsError)
            end

            it 'does not leave any saved claim join objects' do
              expect do
                suppress(described_class::WrongAttachmentsError) do
                  perform
                end
              end.not_to(change(AccreditedRepresentativePortal::SavedClaimClaimantRepresentative, :count))
            end

            it 'does not leave any saved claim objects' do
              expect do
                suppress(described_class::WrongAttachmentsError) do
                  perform
                end
              end.not_to(change(AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim, :count))
            end
          end
        end
      end
    end
  end

  describe '#organize_attachments' do
    let(:form_a) { create(:persistent_attachment_va_form, form_id: '21-686c') }
    let(:form_b) { create(:persistent_attachment_va_form, form_id: '21-686c') }
    let(:attachment_a) { create(:persistent_attachment_va_form_documentation, form_id: '21-686c') }
    let(:saved_claim) { create(:saved_claim_benefits_intake, persistent_attachments: [form_a, attachment_a]) }

    context 'attachment already belongs to a claim' do
      it 'raises WrongAttachmentsError' do
        expect do
          described_class.send(:organize_attachments!, '21-686c', saved_claim.persistent_attachments.pluck(:guid))
        end.to raise_error(described_class::WrongAttachmentsError, 'This attachment already belongs to a claim')
      end
    end

    context 'attachment is for the wrong claim type' do
      it 'raises WrongAttachmentsError' do
        expect do
          described_class.send(:organize_attachments!, '21-526ez', form_a.guid)
        end.to raise_error(described_class::WrongAttachmentsError, 'This attachment is for the wrong claim type')
      end
    end

    context 'no attachments' do
      it 'raises WrongAttachmentsError' do
        expect do
          described_class.send(:organize_attachments!, '21-686c', [])
        end.to raise_error(described_class::WrongAttachmentsError,
                           "Must have 1 form, 0+ documentations, 0 extraneous.\n")
      end
    end

    it 'returns form and documentations' do
      expect(
        described_class.send(:organize_attachments!, '21-686c', [form_a.guid, attachment_a.guid])
      ).to eq({ form: form_a, documentations: [attachment_a] })
    end
  end
end
