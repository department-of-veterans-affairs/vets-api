# frozen_string_literal: true

require 'rails_helper'

require 'benefits_intake_service/service'

RSpec.describe AccreditedRepresentativePortal::SavedClaimService::Attach do
  subject(:perform) { described_class.perform(attachment_klass, file:, form_id:) }

  let(:attachment_klass) { PersistentAttachments::VAFormDocumentation }
  let(:form_id) { AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim::FORM_ID }
  let(:service) { double }

  before do
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

  context 'when record invalid' do
    let(:file) do
      filepath = 'accredited_representative_portal/invalid.pdf'
      fixture_file_upload(filepath, 'application/pdf')
    end

    it 'raises' do
      expect { perform }.to raise_error(
        described_class::RecordInvalidError
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

      allow_any_instance_of(PersistentAttachments::VAFormDocumentation).to(
        receive(:file=)
      )

      allow_any_instance_of(PersistentAttachment).to(
        receive(:validate!)
      )

      allow_any_instance_of(PersistentAttachment).to(
        receive(:to_pdf)
      )
      allow(AccreditedRepresentativePortal::BenefitsIntakeService).to receive(:new).and_return service
    end

    context 'when upstream invalid' do
      before do
        allow(service).to receive(:valid_document?).and_raise(
          BenefitsIntakeService::Service::InvalidDocumentError
        )
      end

      it 'raises' do
        expect { perform }.to raise_error(described_class::UpstreamInvalidError)
      end
    end

    context 'when upstream valid' do
      before do
        allow(service).to receive(:valid_document?)
      end

      it 'returns an attachment' do
        expect(perform).to be_a(PersistentAttachments::VAFormDocumentation)
      end

      context 'when attachment is the main form' do
        let(:attachment_klass) { PersistentAttachments::VAForm }

        it 'returns a VAForm' do
          expect(perform).to be_a(PersistentAttachments::VAForm)
        end
      end
    end
  end
end
