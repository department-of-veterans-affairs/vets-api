# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::FileValidator do
  describe '#validate' do
    let(:fixtures_path) { '/modules/appeals_api/spec/fixtures' }

    let(:valid_pdf) { File.new("#{::Rails.root}#{fixtures_path}/expected_10182_extra.pdf") }
    let(:non_pdf) { File.new("#{::Rails.root}#{fixtures_path}/test_incorrect_type.docx") }
    let(:pretend_pdf) { File.new("#{::Rails.root}#{fixtures_path}/test_fake_pdf.pdf") }
    let(:oversize_pdf) { File.new("#{::Rails.root}#{fixtures_path}/oversize_11x17.pdf") }

    context 'when supported file uploaded' do
      it { expect(described_class.new(valid_pdf).call).to eq([:ok, {}]) }
    end

    context 'when unsupported file type uploaded' do
      it 'returns error data when non-pdf file type' do
        expect(described_class.new(non_pdf).call).to match(
          [
            :error,
            {
              title: 'Invalid file type',
              detail: 'File must be in PDF format.',
              meta: { filename: 'test_incorrect_type.docx' }
            }
          ]
        )
      end

      it 'returns error data if pdf extension but wrong type' do
        expect(described_class.new(pretend_pdf).call).to match(
          [
            :error,
            {
              title: 'Invalid file type',
              detail: 'File must be in PDF format.',
              meta: { filename: 'test_fake_pdf.pdf' }
            }
          ]
        )
      end
    end

    context 'when page dimensions are too large' do
      it 'returns error data' do
        expect(described_class.new(oversize_pdf).call).to match(
          [
            :error,
            {
              title: 'Invalid dimensions',
              detail: 'File exceeds the maximum page dimensions.',
              meta: {
                filename: 'oversize_11x17.pdf',
                max_page_size_inches: { width: 11, height: 11 },
                page_dimensions_inches: { width: 17.0, height: 11.0 }
              }
            }
          ]
        )
      end
    end

    context 'when file size is too large' do
      let(:path) { "#{::Rails.root}#{fixtures_path}/expected_10182_extra.pdf" }
      let(:big_file) { instance_double('File', to_path: path, path: path, size: 200.megabytes) }

      it 'returns error data' do
        expect(described_class.new(big_file).call).to match(
          [
            :error,
            {
              title: 'Invalid file size',
              detail: 'File is too large.',
              meta:
                {
                  filename: 'expected_10182_extra.pdf',
                  max_file_size: '100 MB',
                  file_size: '209 MB'
                }
            }
          ]
        )
      end
    end
  end
end
