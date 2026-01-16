# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupportingEvidenceAttachment, type: :model do
  describe '#obscured_filename' do
    context 'for a filename exceeding the maximum length' do
      let(:long_filename) { "#{'a' * 300}.pdf" } # 300 characters + extension
      let(:attachment) do
        build(
          :supporting_evidence_attachment,
          file_data: { filename: long_filename }.to_json
        )
      end

      it 'truncates the filename to a safe length' do
        expect(attachment.obscured_filename.length).to be <= 255
        expect(attachment.obscured_filename).to end_with('.pdf')
      end
    end

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
