# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::EvidenceSubmission::FileValidator do
  describe '#validate' do
    let(:fixtures_path) { '/modules/appeals_api/spec/fixtures' }

    let(:valid_pdf) { File.new("#{::Rails.root}#{fixtures_path}/expected_10182_extra.pdf") }
    let(:non_pdf) { File.new("#{::Rails.root}#{fixtures_path}/test_incorrect_type.docx") }
    let(:pretend_pdf) { File.new("#{::Rails.root}#{fixtures_path}/test_fake_pdf.pdf") }
    let(:oversize_pdf) { File.new("#{::Rails.root}#{fixtures_path}/oversize_11x17.pdf") }

    context 'when supported file uploaded (100MB 11in x 11in PDF)' do
      it 'return success data' do
        expect(described_class.new(valid_pdf).call).to match(
          document:
            {
              status: 'accepted',
              filename: 'expected_10182_extra.pdf',
              pages: 4,
              detail: 'File validated',
              file_dimensions: { height: 8.5, width: 11.0 }
            }
        )
      end
    end

    context 'when unsupported file type uploaded' do
      it 'returns error data when non-pdf file type' do
        expect(described_class.new(non_pdf).call).to match(
          document:
            {
              status: 'error',
              filename: 'test_incorrect_type.docx',
              detail: 'File must be in PDF format',
              file_extension: '.docx'
            }
        )
      end

      it 'returns error data if pdf extension but wrong type' do
        expect(described_class.new(pretend_pdf).call).to match(
          document:
            {
              status: 'error',
              filename: 'test_fake_pdf.pdf',
              detail: 'File must be in PDF format',
              file_extension: '.pdf is likely an incorrect extension for this document'
            }
        )
      end
    end

    context 'when page dimensions are too large' do
      it 'returns error data' do
        expect(described_class.new(oversize_pdf).call).to match(
          document:
            {
              status: 'error',
              filename: 'oversize_11x17.pdf',
              pages: 1,
              detail: 'File exceeds the maximum page dimensions of 11 inches x 11 inches',
              file_dimensions: { height: 11.0, width: 17.0 }
            }
        )
      end
    end

    context 'when file size is too large' do
      before { allow_any_instance_of(described_class).to receive(:valid_file_size?).and_return(false) }

      it 'returns error data' do
        expect(described_class.new(valid_pdf).call).to match(
          document:
            {
              status: 'error',
              filename: 'expected_10182_extra.pdf',
              pages: 4,
              detail: 'File cannot exceed a file size of 100 megabytes',
              file_size: '83846 MB'
            }
        )
      end
    end
  end
end
