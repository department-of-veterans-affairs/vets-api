# frozen_string_literal: true

require 'rails_helper'

require 'benefits_intake_service/service'

RSpec.describe AccreditedRepresentativePortal::SavedClaimService::Attach do
  subject(:perform) { described_class.perform(file, is_form:) }

  let(:is_form) { false }

  context 'when record invalid' do
    let(:file) do
      filepath = 'accredited_representative_portal/invalid.pdf'
      fixture_file_upload(filepath, 'application/pdf')
    end

    it 'raises' do
      expect { perform }.to raise_error(
        described_class::InvalidFileError
      )
    end
  end

  context 'when record valid' do
    let(:file) { Object.new } # Not actually used.

    ##
    # Brittle mocking as no-op of everything leading up to the upstream validity
    # check.
    #
    before do
      allow_any_instance_of(PersistentAttachments::VAForm).to(
        receive(:file=)
      )

      allow_any_instance_of(PersistentAttachments::VAFormAttachment).to(
        receive(:file=)
      )

      allow_any_instance_of(PersistentAttachment).to(
        receive(:validate!)
      )

      allow_any_instance_of(PersistentAttachment).to(
        receive(:to_pdf)
      )
    end

    context 'when upstream invalid' do
      before do
        allow_any_instance_of(BenefitsIntakeService::Service).to(
          receive(:valid_document?).and_raise(
            BenefitsIntakeService::Service::InvalidDocumentError
          )
        )
      end

      it 'raises' do
        expect { perform }.to raise_error(
          described_class::InvalidFileError
        )
      end
    end

    context 'when upstream valid' do
      before do
        allow_any_instance_of(BenefitsIntakeService::Service).to(
          receive(:valid_document?)
        )
      end

      it 'returns an attachment' do
        expect(perform).to be_a(
          PersistentAttachments::VAFormAttachment
        )
      end

      context 'when attachment is the main form' do
        let(:is_form) { true }

        it 'returns a VAForm' do
          expect(perform).to be_a(
            PersistentAttachments::VAForm
          )
        end
      end
    end
  end
end
