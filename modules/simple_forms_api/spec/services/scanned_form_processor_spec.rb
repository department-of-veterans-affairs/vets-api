# frozen_string_literal: true

require 'rails_helper'
require 'common/convert_to_pdf'
require 'common/pdf_helpers'

RSpec.describe SimpleFormsApi::ScannedFormProcessor do
  let(:pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
  let(:jpg_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg') }
  let(:encrypted_pdf_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_encryption.pdf') }
  let(:correct_password) { 'test' }
  let(:wrong_password) { 'wrongpassword' }

  describe '#process!' do
    context 'with a fresh file upload' do
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

      it 'accepts an attachment without password' do
        processor = described_class.new(fresh_attachment)
        expect(processor).to be_a(described_class)
      end

      it 'accepts an attachment with password' do
        processor = described_class.new(fresh_attachment, password: 'testpass123')
        expect(processor).to be_a(described_class)
      end

      it 'processes successfully with fresh file upload' do
        expect { processor.process! }.not_to raise_error
        expect(fresh_attachment.persisted?).to be true
      end

      it 'does not attempt decryption for unencrypted PDFs' do
        expect(Common::PdfHelpers).not_to receive(:unlock_pdf)
        processor.process!
      end
    end

    context 'with encrypted PDF and correct password' do
      let(:attachment) do
        PersistentAttachments::VAForm.new.tap do |att|
          att.form_id = '21-0779'
          att.file_attacher.attach(File.open(encrypted_pdf_path, 'rb'), validate: false)
        end
      end
      let(:processor) { described_class.new(attachment, password: correct_password) }

      before do
        allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(
          double(validate: double(valid_pdf?: true, errors: []))
        )
        allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_unlocked_pdf)
        allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_pdf_page_count)
      end

      it 'calls Common::PdfHelpers.unlock_pdf with correct parameters' do
        expect(Common::PdfHelpers).to receive(:unlock_pdf).with(
          anything,
          correct_password,
          anything
        ).and_call_original

        processor.process!
      end

      it 'processes successfully after decryption' do
        expect { processor.process! }.not_to raise_error
        expect(attachment.persisted?).to be true
      end
    end

    context 'with encrypted PDF and wrong password' do
      let(:attachment) do
        PersistentAttachments::VAForm.new.tap do |att|
          att.form_id = '21-0779'
          att.file_attacher.attach(File.open(encrypted_pdf_path, 'rb'), validate: false)
        end
      end
      let(:processor) { described_class.new(attachment, password: wrong_password) }

      it 'raises ValidationError with password message' do
        expect { processor.process! }
          .to raise_error(SimpleFormsApi::ScannedFormProcessor::ValidationError) do |error|
            expect(error.message).to eq('PDF decryption failed')
            expect(error.errors).to include(
              hash_including(
                title: 'Invalid password',
                detail: 'The password you entered is incorrect. Please try again.'
              )
            )
          end
      end
    end

    context 'with encrypted PDF and no password' do
      let(:attachment) do
        PersistentAttachments::VAForm.new.tap do |att|
          att.form_id = '21-0779'
          att.file_attacher.attach(File.open(encrypted_pdf_path, 'rb'), validate: false)
        end
      end
      let(:processor) { described_class.new(attachment) }

      before do
        allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(
          double(validate: double(valid_pdf?: false, errors: ['Document is locked with a user password']))
        )
      end

      it 'raises ValidationError when PDF cannot be read' do
        expect { processor.process! }
          .to raise_error(SimpleFormsApi::ScannedFormProcessor::ValidationError) do |error|
            expect(error.message).to eq('PDF validation failed')
            expect(error.errors.first[:detail]).to eq('Document is locked with a user password')
          end
      end
    end

    context 'cleanup of decrypted files' do
      let(:attachment) do
        PersistentAttachments::VAForm.new.tap do |att|
          att.form_id = '21-0779'
          att.file_attacher.attach(File.open(encrypted_pdf_path, 'rb'), validate: false)
        end
      end
      let(:processor) { described_class.new(attachment, password: correct_password) }

      before do
        allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(
          double(validate: double(valid_pdf?: true, errors: []))
        )
      end

      it 'cleans up decrypted temp file after successful processing' do
        decrypted_path = nil

        allow(processor).to receive(:decrypt_pdf).and_wrap_original do |method, *args|
          result = method.call(*args)
          decrypted_path = result
          result
        end

        processor.process!

        expect(decrypted_path).not_to be_nil
        expect(File.exist?(decrypted_path)).to be false
      end

      it 'cleans up decrypted temp file even when validation fails' do
        decrypted_path = nil

        allow(processor).to receive(:decrypt_pdf).and_wrap_original do |method, *args|
          result = method.call(*args)
          decrypted_path = result
          result
        end

        # Make validation fail
        allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(
          double(validate: double(valid_pdf?: false, errors: ['Test error']))
        )

        expect { processor.process! }.to raise_error(SimpleFormsApi::ScannedFormProcessor::ValidationError)

        expect(decrypted_path).not_to be_nil
        expect(File.exist?(decrypted_path)).to be false
      end
    end

    context 'with unencrypted PDF and password parameter' do
      let(:attachment) do
        PersistentAttachments::VAForm.new.tap do |att|
          att.form_id = '21-0779'
          att.file = File.open(pdf_path, 'rb')
        end
      end
      let(:processor) { described_class.new(attachment, password: 'unused_password') }

      before do
        allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(
          double(validate: double(valid_pdf?: true, errors: []))
        )
      end

      it 'processes successfully even with unnecessary password' do
        expect { processor.process! }.not_to raise_error
        expect(attachment.persisted?).to be true
      end
    end

    context 'end-to-end encrypted PDF processing without mocks' do
      let(:attachment) do
        PersistentAttachments::VAForm.new.tap do |att|
          att.form_id = '21-0779'
          att.file_attacher.attach(File.open(encrypted_pdf_path, 'rb'), validate: false)
        end
      end
      let(:processor) { described_class.new(attachment, password: correct_password) }

      it 'successfully decrypts, validates, and saves the PDF' do
        expect { processor.process! }.not_to raise_error
        expect(attachment.persisted?).to be true

        attachment.reload

        pdf_content = attachment.file.read
        expect(pdf_content).to start_with('%PDF-')
        expect(attachment.file.content_type).to eq('application/pdf')

        temp_pdf = Tempfile.new(['decrypted_verify', '.pdf'])
        temp_pdf.binmode
        temp_pdf.write(pdf_content)
        temp_pdf.close

        doc = HexaPDF::Document.open(temp_pdf.path)
        expect(doc.encrypted?).to be false

        temp_pdf.unlink
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

  context 'when attachment persistence fails' do
    let(:attachment) do
      PersistentAttachments::VAForm.new.tap do |att|
        att.form_id = '21-0779'
        att.file = File.open(jpg_path, 'rb')
      end
    end
    let(:processor) { described_class.new(attachment) }
    let(:temp_pdf) do
      file = Tempfile.new(['processed', '.pdf'])
      file.binmode
      file.write('%PDF-1.4 test')
      file.close
      file
    end

    before do
      allow(Common::ConvertToPdf).to receive(:new).and_return(double(run: temp_pdf.path))
      allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(
        double(validate: double(valid_pdf?: true, errors: []))
      )
      allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_correct_form)
      allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_pdf_page_count)
      allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_unlocked_pdf)
      allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_max_width)
      allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_max_height)
      allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_max_size)
      allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_min_size)
      allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_mime_type_inclusion)
      allow_any_instance_of(FormUpload::Uploader::Attacher).to receive(:validate_virus_free)
    end

    after do
      temp_pdf.unlink if File.exist?(temp_pdf.path)
    rescue Errno::ENOENT
      nil
    end

    it 'raises PersistenceError with validation messages when save! fails' do
      attachment.errors.add(:base, 'database unavailable')
      allow(attachment).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(attachment))

      expect { processor.process! }
        .to raise_error(SimpleFormsApi::ScannedFormProcessor::PersistenceError) do |error|
          expect(error.errors.first[:detail]).to eq('database unavailable')
        end
    end

    it 'raises PersistenceError with a default message on unexpected errors' do
      attachment.errors.clear
      allow(attachment).to receive(:save!).and_raise(StandardError, 'boom')

      expect { processor.process! }
        .to raise_error(SimpleFormsApi::ScannedFormProcessor::PersistenceError) do |error|
          expect(error.errors.first[:detail]).to include('save your file')
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

  context 'Shrine validations after decryption' do
    let(:attachment) do
      PersistentAttachments::VAForm.new.tap do |att|
        att.form_id = '21-0779'
        att.file_attacher.attach(File.open(encrypted_pdf_path, 'rb'), validate: false)
      end
    end
    let(:processor) { described_class.new(attachment, password: correct_password) }

    before do
      allow(PDFUtilities::PDFValidator::Validator).to receive(:new).and_return(
        double(validate: double(valid_pdf?: true, errors: []))
      )
    end

    it 'triggers Shrine validations after decryption' do
      expect(attachment).to receive(:file=).and_call_original
      expect(attachment).to receive(:valid?).and_call_original

      processor.process!
    end
  end
end
