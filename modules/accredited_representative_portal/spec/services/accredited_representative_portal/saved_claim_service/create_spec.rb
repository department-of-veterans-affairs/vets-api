# frozen_string_literal: true

require 'rails_helper'

def load_fixture(path_suffix)
  dir = './create_spec/fixtures'
  File.expand_path("#{dir}/#{path_suffix}", __dir__)
      .then { |path| File.read(path) }
      .then { |json| JSON.parse(json) }
end

dependent_claimant_form =
  load_fixture('dependent_claimant_form.json')

RSpec.describe AccreditedRepresentativePortal::SavedClaimService::Create do
  subject(:perform) do
    described_class.perform(
      type: AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim,
      attachment_guids: attachments.map(&:guid),
      metadata:
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

          it 'returns a saved claim' do
            expect(perform).to be_a(
              AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
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

          it 'returns a saved claim' do
            expect(perform).to be_a(
              AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
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
