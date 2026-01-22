# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupportingEvidenceAttachment, type: :model do
  describe '#shorten_filename (private method)' do
    let(:attachment) { build(:supporting_evidence_attachment) }

    context 'when filename exceeds MAX_FILENAME_LENGTH' do
      it 'shortens the filename while preserving extension' do
        long_filename = "#{'a' * 120}.pdf" # 124 characters
        shortened = attachment.send(:shorten_filename, long_filename)

        expect(shortened.length).to eq(100) # Exactly at MAX_FILENAME_LENGTH
        expect(shortened).to end_with('.pdf')
        expect(shortened).to start_with('a' * 96) # 96 + 4 for '.pdf' = 100
      end

      it 'handles different extensions correctly' do
        long_filename = "#{'test' * 30}.jpeg" # 125 characters
        shortened = attachment.send(:shorten_filename, long_filename)

        expect(shortened.length).to eq(100)
        expect(shortened).to end_with('.jpeg')
      end

      it 'handles files with no extension' do
        long_filename = 'a' * 120 # 120 characters, no extension
        shortened = attachment.send(:shorten_filename, long_filename)

        expect(shortened.length).to eq(100)
        expect(shortened).to eq('a' * 100)
      end
    end

    context 'when filename is within MAX_FILENAME_LENGTH' do
      it 'does not modify short filenames' do
        short_filename = 'document.pdf'
        shortened = attachment.send(:shorten_filename, short_filename)

        expect(shortened).to eq('document.pdf')
      end

      it 'does not modify filenames exactly at the limit' do
        exact_filename = "#{'a' * 96}.pdf" # Exactly 100 characters
        shortened = attachment.send(:shorten_filename, exact_filename)

        expect(shortened).to eq(exact_filename)
        expect(shortened.length).to eq(100)
      end
    end
  end

  describe '#set_file_data! (integration style)' do
    let(:attachment) { build(:supporting_evidence_attachment) }

    before do
      # Stub the S3 storage parts to avoid actual file uploads
      allow_any_instance_of(SupportingEvidenceAttachmentUploader).to receive(:store!)
      allow_any_instance_of(SupportingEvidenceAttachmentUploader).to receive(:converted_exists?).and_return(false)
    end

    it 'shortens long filenames using real file objects' do
      # Create a real uploaded file with a long filename
      long_filename = "#{'evidence' * 20}.pdf" # 140+ characters
      uploaded_file = fixture_file_upload('doctors-note.pdf', 'application/pdf')
      allow(uploaded_file).to receive(:original_filename).and_return(long_filename)

      # Allow the uploader to return long filename
      allow_any_instance_of(SupportingEvidenceAttachmentUploader).to receive(:filename).and_return(long_filename)

      attachment.set_file_data!(uploaded_file)

      file_data = JSON.parse(attachment.file_data)
      expect(file_data['filename'].length).to be <= SupportingEvidenceAttachment::MAX_FILENAME_LENGTH
      expect(file_data['filename']).to end_with('.pdf')
    end

    it 'preserves short filenames using real file objects' do
      short_filename = 'medical-record.pdf'
      uploaded_file = fixture_file_upload('doctors-note.pdf', 'application/pdf')
      allow(uploaded_file).to receive(:original_filename).and_return(short_filename)

      allow_any_instance_of(SupportingEvidenceAttachmentUploader).to receive(:filename).and_return(short_filename)

      attachment.set_file_data!(uploaded_file)

      file_data = JSON.parse(attachment.file_data)
      expect(file_data['filename']).to eq('medical-record.pdf')
    end
  end

  describe '#set_file_data!' do
    let(:attachment) { build(:supporting_evidence_attachment) }
    let(:mock_uploader) { instance_double(SupportingEvidenceAttachmentUploader) }
    let(:mock_file) { instance_double(ActionDispatch::Http::UploadedFile, tempfile: mock_tempfile) }
    let(:mock_tempfile) { instance_double(Tempfile, path: '/tmp/test.pdf') }

    before do
      allow(attachment).to receive(:get_attachment_uploader).and_return(mock_uploader)
      allow(mock_uploader).to receive(:store!)
      allow(mock_uploader).to receive_messages(filename:, converted_exists?: converted_exists)
      # Mock File.extname to return the expected extension
      allow(File).to receive(:extname).and_call_original
      allow(File).to receive(:extname).with(mock_file).and_return('.pdf')
    end

    context 'when filename exceeds MAX_FILENAME_LENGTH' do
      let(:filename) { "#{'a' * 120}.pdf" } # 124 characters
      let(:converted_exists) { false }

      it 'shortens the original filename' do
        attachment.set_file_data!(mock_file)

        file_data = JSON.parse(attachment.file_data)
        expect(file_data['filename'].length).to be <= SupportingEvidenceAttachment::MAX_FILENAME_LENGTH
        expect(file_data['filename']).to end_with('.pdf')
        expect(file_data['filename'].length).to eq(100) # Exactly at the limit
      end
    end

    context 'when filename is within MAX_FILENAME_LENGTH' do
      let(:filename) { 'short_filename.pdf' }
      let(:converted_exists) { false }

      it 'does not shorten the filename' do
        attachment.set_file_data!(mock_file)

        file_data = JSON.parse(attachment.file_data)
        expect(file_data['filename']).to eq('short_filename.pdf')
      end
    end

    context 'when converted file exists' do
      let(:filename) { 'normal_file.pdf' }
      let(:converted_exists) { true }
      let(:converted_filename) { "converted_#{'a' * 120}.jpg" } # Long converted filename

      before do
        allow(mock_uploader).to receive(:final_filename).and_return(converted_filename)
      end

      it 'shortens both original and converted filenames' do
        attachment.set_file_data!(mock_file)

        file_data = JSON.parse(attachment.file_data)
        expect(file_data['filename']).to eq('normal_file.pdf')
        expect(file_data['converted_filename'].length).to be <= SupportingEvidenceAttachment::MAX_FILENAME_LENGTH
        expect(file_data['converted_filename']).to end_with('.jpg')
      end
    end

    context 'when both original and converted filenames are long' do
      let(:filename) { "#{'a' * 120}.tiff" }
      let(:converted_exists) { true }
      let(:converted_filename) { "converted_#{'b' * 120}.jpg" }

      before do
        allow(mock_uploader).to receive(:final_filename).and_return(converted_filename)
      end

      it 'shortens both filenames independently' do
        attachment.set_file_data!(mock_file)

        file_data = JSON.parse(attachment.file_data)

        # Original should be shortened
        expect(file_data['filename'].length).to be <= SupportingEvidenceAttachment::MAX_FILENAME_LENGTH
        expect(file_data['filename']).to end_with('.tiff')

        # Converted should be shortened
        expect(file_data['converted_filename'].length).to be <= SupportingEvidenceAttachment::MAX_FILENAME_LENGTH
        expect(file_data['converted_filename']).to end_with('.jpg')

        # Should be different shortened strings
        expect(file_data['filename']).not_to eq(file_data['converted_filename'])
      end
    end
  end

  describe '#obscured_filename' do
    context 'for a filename longer than five characters' do
      context 'for a filename containing letters' do
        let(:attachment) do
          build(
            :supporting_evidence_attachment,
            file_data: { filename: 'MySecretFile.pdf' }.to_json
          )
        end

        it 'obscures all but the first 3 and last 2 characters of the filename' do
          expect(attachment.obscured_filename).to eq('MySXXXXXXXle.pdf')
        end
      end

      context 'for a filename containing numbers' do
        let(:attachment) do
          build(
            :supporting_evidence_attachment,
            file_data: { filename: 'MySecretFile123.pdf' }.to_json
          )
        end

        it 'obscures the filename' do
          expect(attachment.obscured_filename).to eq('MySXXXXXXXXXX23.pdf')
        end
      end

      context 'for a filename containing underscores' do
        let(:attachment) do
          build(
            :supporting_evidence_attachment,
            file_data: { filename: 'MySecretFile_123.pdf' }.to_json
          )
        end

        it 'does not obscure the underscores' do
          expect(attachment.obscured_filename).to eq('MySXXXXXXXXX_X23.pdf')
        end
      end

      context 'for a filename containing dashes' do
        let(:attachment) do
          build(
            :supporting_evidence_attachment,
            file_data: { filename: 'MySecretFile-123.pdf' }.to_json
          )
        end

        it 'does not obscure the dashes' do
          expect(attachment.obscured_filename).to eq('MySXXXXXXXXX-X23.pdf')
        end
      end

      # Ensure Regexp still handles the file extension properly
      context 'for a filename containing a dot' do
        let(:attachment) do
          build(
            :supporting_evidence_attachment,
            file_data: { filename: 'MySecret.File123.pdf' }.to_json
          )
        end

        it 'obsucres the filename properly' do
          expect(attachment.obscured_filename).to eq('MySXXXXX.XXXXX23.pdf')
        end
      end

      context 'for a filename containing whitespace' do
        let(:attachment) do
          build(
            :supporting_evidence_attachment,
            file_data: { filename: 'My Secret File.pdf' }.to_json
          )
        end

        it 'preserves the whitespace' do
          expect(attachment.obscured_filename).to eq('My XXXXXX XXle.pdf')
        end
      end
    end

    context 'for a filename with five characters or less' do
      let(:attachment) do
        build(
          :supporting_evidence_attachment,
          file_data: { filename: 'File.pdf' }.to_json
        )
      end

      it 'does not obscure the filename' do
        expect(attachment.obscured_filename).to eq('File.pdf')
      end
    end

    # NOTE: Filetypes that need to be converted in EVSSClaimDocumentUploaderBase
    # have 'converted_' prepended to the file name and saved as converted_filename in the file_data
    # Ensure the obscured_filename method is masking the original filename
    # This is the name of the file the veteran originally uploaded so it will be recognizable to them
    context 'for a file with a converted file name' do
      let(:attachment) do
        build(
          :supporting_evidence_attachment,
          file_data: {
            filename: 'File123.pdf',
            converted_filename: 'converted_File123.pdf'
          }.to_json
        )
      end

      it 'obscures the original filename' do
        expect(attachment.obscured_filename).to eq('FilXX23.pdf')
      end
    end
  end
end
