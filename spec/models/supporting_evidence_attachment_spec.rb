# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupportingEvidenceAttachment, type: :model do
  describe '#set_file_data! (integration style)' do
    let(:attachment) { build(:supporting_evidence_attachment) }
    let(:mock_file) { double('CarrierWave::SanitizedFile') }

    before do
      # Stub the S3 storage parts to avoid actual file uploads
      allow_any_instance_of(SupportingEvidenceAttachmentUploader).to receive(:store!)
      allow_any_instance_of(SupportingEvidenceAttachmentUploader).to receive(:converted_exists?).and_return(false)

      # Mock the file object that gets returned after storage
      allow_any_instance_of(SupportingEvidenceAttachmentUploader).to receive(:file).and_return(mock_file)
    end

    it 'shortens long filenames using real file objects' do
      # Create a real uploaded file with a long filename
      long_filename = "#{'evidence' * 20}.pdf" # 140+ characters
      uploaded_file = fixture_file_upload('doctors-note.pdf', 'application/pdf')
      allow(uploaded_file).to receive(:original_filename).and_return(long_filename)

      # Mock what the uploader.filename should return after storage (shortened)
      shortened_filename = "#{'evidence' * 12}.pdf" # Should be shortened to 100 chars
      allow_any_instance_of(SupportingEvidenceAttachmentUploader).to receive(:filename).and_return(shortened_filename)

      attachment.set_file_data!(uploaded_file)

      file_data = JSON.parse(attachment.file_data)
      expect(file_data['filename']).to eq(shortened_filename)
      expect(file_data['original_filename']).to eq(long_filename)
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
      expect(file_data['original_filename']).to eq('medical-record.pdf')
    end
  end

  describe '#set_file_data!' do
    let(:attachment) { build(:supporting_evidence_attachment) }
    let(:mock_uploader) { instance_double(SupportingEvidenceAttachmentUploader) }
    let(:mock_file) { instance_double(ActionDispatch::Http::UploadedFile, tempfile: mock_tempfile, original_filename: 'test.pdf') }
    let(:mock_tempfile) { instance_double(Tempfile, path: '/tmp/test.pdf') }
    let(:mock_stored_file) { double('CarrierWave::SanitizedFile') }

    before do
      allow(attachment).to receive(:get_attachment_uploader).and_return(mock_uploader)
      allow(mock_uploader).to receive(:store!)
      allow(mock_uploader).to receive(:file).and_return(mock_stored_file)
      allow(mock_uploader).to receive_messages(filename:, converted_exists?: converted_exists)
      # Mock File.extname to return the expected extension
      allow(File).to receive(:extname).and_call_original
      allow(File).to receive(:extname).with(mock_file).and_return('.pdf')
    end

    context 'when filename exceeds MAX_FILENAME_LENGTH' do
      let(:filename) { "#{'a' * 96}.pdf" } # 100 characters (already shortened by uploader)
      let(:converted_exists) { false }

      it 'stores the shortened filename from uploader' do
        allow(mock_stored_file).to receive(:filename).and_return(filename)
        allow(mock_file).to receive(:original_filename).and_return("#{'a' * 96}.pdf")

        attachment.set_file_data!(mock_file)

        file_data = JSON.parse(attachment.file_data)
        expect(file_data['filename']).to eq(filename)
        expect(file_data['original_filename']).to eq("#{'a' * 96}.pdf")
        expect(file_data['filename'].length).to be <= SupportingEvidenceAttachment::MAX_FILENAME_LENGTH
      end
    end

    context 'when filename is within MAX_FILENAME_LENGTH' do
      let(:filename) { 'short_filename.pdf' }
      let(:converted_exists) { false }

      it 'does not shorten the filename' do
        allow(mock_stored_file).to receive(:filename).and_return(filename)
        allow(mock_file).to receive(:original_filename).and_return('short_filename.pdf')

        attachment.set_file_data!(mock_file)

        file_data = JSON.parse(attachment.file_data)
        expect(file_data['filename']).to eq('short_filename.pdf')
        expect(file_data['original_filename']).to eq('short_filename.pdf')
      end
    end

    context 'when converted file exists' do
      let(:filename) { 'normal_file.pdf' }
      let(:converted_exists) { true }
      let(:converted_filename) { 'converted_normal_file.jpg' } # Already shortened by uploader
      let(:mock_converted_version) { double('ConvertedVersion') }
      let(:mock_converted_file) { double('CarrierWave::SanitizedFile') }

      before do
        allow(mock_uploader).to receive(:converted).and_return(mock_converted_version)
        allow(mock_converted_version).to receive(:file).and_return(mock_converted_file)
        allow(mock_converted_file).to receive(:filename).and_return(converted_filename)
      end

      it 'includes both original and converted filenames' do
        allow(mock_stored_file).to receive(:filename).and_return(filename)
        allow(mock_file).to receive(:original_filename).and_return('normal_file.pdf')

        attachment.set_file_data!(mock_file)

        file_data = JSON.parse(attachment.file_data)
        expect(file_data['filename']).to eq('normal_file.pdf')
        expect(file_data['original_filename']).to eq('normal_file.pdf')
        expect(file_data['converted_filename']).to eq('converted_normal_file.jpg')
      end
    end

    context 'when both original and converted filenames are long' do
      let(:filename) { "#{'a' * 95}.tiff" } # 100 chars (shortened by uploader)
      let(:converted_exists) { true }
      let(:long_converted_filename) { "converted_#{'b' * 140}.jpg" } # 150+ chars - too long
      let(:mock_converted_version) { double('ConvertedVersion') }
      let(:mock_converted_file) { double('CarrierWave::SanitizedFile') }

      before do
        allow(mock_uploader).to receive(:converted).and_return(mock_converted_version)
        allow(mock_converted_version).to receive(:file).and_return(mock_converted_file)
        allow(mock_converted_file).to receive(:filename).and_return(long_converted_filename)
        allow(mock_uploader).to receive(:send).with(:shorten_filename,
                                                    long_converted_filename).and_return(
                                                      "#{long_converted_filename[0, 96]}.jpg"
                                                    )
      end

      it 'includes both shortened filenames from uploader' do
        original_long_filename = "#{'b' * 95}.tiff" # 100 chars
        allow(mock_stored_file).to receive(:filename).and_return(filename)
        allow(mock_file).to receive(:original_filename).and_return(original_long_filename)

        attachment.set_file_data!(mock_file)

        file_data = JSON.parse(attachment.file_data)

        # Original should be already shortened by the uploader
        expect(file_data['filename']).to eq(filename)
        expect(file_data['original_filename']).to eq(original_long_filename)
        expect(file_data['filename'].length).to eq(100)
        expect(file_data['filename']).to end_with('.tiff')

        # Converted should be shortened by the model's set_file_data! method
        expect(file_data['converted_filename'].length).to be <= 100
        expect(file_data['converted_filename']).to end_with('.jpg')
        expect(file_data['converted_filename']).to start_with('converted_')

        # Should be different shortened strings
        expect(file_data['filename']).not_to eq(file_data['converted_filename'])
      end
    end

    context 'when file system encounters filename too long error' do
      let(:filename) { 'test.pdf' }
      let(:converted_exists) { false }

      it 'converts Errno::ENAMETOOLONG to UnprocessableEntity' do
        allow(mock_stored_file).to receive(:filename).and_return(filename)
        allow(mock_file).to receive(:original_filename).and_return('test.pdf')
        allow(mock_uploader).to receive(:store!).and_raise(Errno::ENAMETOOLONG, 'File name too long')

        expect(Rails.logger).to receive(:error).with(
          'SupportingEvidenceAttachment filename too long error',
          hash_including(error: a_string_including('File name too long'))
        )

        expect { attachment.set_file_data!(mock_file) }
          .to raise_error(Common::Exceptions::UnprocessableEntity) do |error|
            expect(error.errors.first.detail).to eq('File name is too long. Please use a shorter file name.')
            expect(error.errors.first.source).to eq('SupportingEvidenceAttachment.set_file_data')
          end
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
