# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupportingEvidenceAttachment, type: :model do
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

  describe '#get_file' do
    context 'when original upload had a long filename' do
      let(:long_filename) { "#{'a' * 200}.pdf" }

      it 'retrieves the file without ENAMETOOLONG error' do
        file = Rack::Test::UploadedFile.new(
          Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf'),
          'application/pdf'
        )
        allow(file).to receive(:original_filename).and_return(long_filename)

        attachment = described_class.new(guid: SecureRandom.uuid)
        attachment.set_file_data!(file)
        attachment.save!

        expect { attachment.get_file }.not_to raise_error
        expect(attachment.get_file).to be_present
        expect(attachment.parsed_file_data['filename'].length).to be <= SupportingEvidenceAttachmentUploader::MAX_FILENAME_LENGTH
      end
    end

    context 'with a filename at the maximum allowed length' do
      # Test with exactly MAX_FILENAME_LENGTH to verify edge case
      let(:max_length_filename) do
        extension = '.pdf'
        basename_length = SupportingEvidenceAttachmentUploader::MAX_FILENAME_LENGTH - extension.length
        "#{'x' * basename_length}#{extension}"
      end

      it 'stores and retrieves the file correctly' do
        file = Rack::Test::UploadedFile.new(
          Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf'),
          'application/pdf'
        )
        allow(file).to receive(:original_filename).and_return(max_length_filename)

        attachment = described_class.new(guid: SecureRandom.uuid)
        attachment.set_file_data!(file)
        attachment.save!

        stored_filename = attachment.parsed_file_data['filename']
        expect(stored_filename.length).to eq(SupportingEvidenceAttachmentUploader::MAX_FILENAME_LENGTH)
        expect { attachment.get_file }.not_to raise_error
      end
    end
  end
end
