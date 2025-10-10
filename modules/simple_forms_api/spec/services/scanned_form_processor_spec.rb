# frozen_string_literal: true

require 'rails_helper'
require 'common/convert_to_pdf'

RSpec.describe SimpleFormsApi::ScannedFormProcessor do
  let(:pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
  let(:jpg_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg') }

  describe '#process!' do
    context 'with a fresh file upload (should work)' do
      let(:fresh_attachment) do
        PersistentAttachments::VAForm.new.tap do |attachment|
          attachment.form_id = '21-0779'
          attachment.file = File.open(jpg_path, 'rb')
        end
      end
      let(:processor) { described_class.new(fresh_attachment) }

      before do
        allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(
          double(validate: double(valid_pdf?: true, errors: []))
        )
      end

      it 'processes successfully with fresh file upload' do
        expect { processor.process! }.not_to raise_error
        expect(fresh_attachment.persisted?).to be true
      end
    end

    context 'testing conversion errors' do
      let(:attachment) do
        PersistentAttachments::VAForm.new.tap do |att|
          att.form_id = '21-0779'
          att.file = File.open(jpg_path, 'rb')
        end
      end
      let(:processor) { described_class.new(attachment) }

      before do
        allow(Common::ConvertToPdf).to receive(:new).and_raise(StandardError.new('Conversion failed'))
      end

      it 'raises ConversionError when conversion fails' do
        error = nil
        expect { processor.process! }
          .to raise_error(SimpleFormsApi::ScannedFormProcessor::ConversionError) { |e| error = e }

        expect(error.message).to eq('File conversion failed')
        expect(error.errors.first[:title]).to eq('File conversion error')
      end
    end

    context 'testing validation errors' do
      let(:attachment) do
        PersistentAttachments::VAForm.new.tap do |att|
          att.form_id = '21-0779'
          att.file = File.open(pdf_path, 'rb')
        end
      end
      let(:processor) { described_class.new(attachment) }

      before do
        failed_validation = double(
          valid_pdf?: false,
          errors: ['File too large', 'Invalid format']
        )
        allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(
          double(validate: failed_validation)
        )
      end

      it 'raises ValidationError when PDF validation fails' do
        expect { processor.process! }
          .to raise_error(SimpleFormsApi::ScannedFormProcessor::ValidationError)

        begin
          processor.process!
        rescue SimpleFormsApi::ScannedFormProcessor::ValidationError => e
          expect(e.message).to eq('PDF validation failed')
          expect(e.errors).to contain_exactly(
            { title: 'File validation error', detail: 'File too large' },
            { title: 'File validation error', detail: 'Invalid format' }
          )
        end
      end
    end
  end

  context 'end-to-end processing without mocks' do
    let(:attachment) do
      PersistentAttachments::VAForm.new.tap do |att|
        att.form_id = '21-0779'
        att.file = File.open(jpg_path, 'rb')
      end
    end
    let(:processor) { described_class.new(attachment) }

    it 'successfully converts JPG to PDF and validates the result' do
      expect { processor.process! }.not_to raise_error
      expect(attachment.persisted?).to be true
      attachment.reload
      pdf_content = attachment.file.read
      expect(pdf_content).to start_with('%PDF-')
      expect(attachment.file.content_type).to eq('application/pdf')
      temp_pdf = Tempfile.new(['converted', '.pdf'])
      temp_pdf.binmode
      temp_pdf.write(pdf_content)
      temp_pdf.close
      validator = PDFUtilities::PDFValidator::Validator.new(temp_pdf.path)
      expect(validator.validate.valid_pdf?).to be true

      temp_pdf.unlink
    end
  end
end
