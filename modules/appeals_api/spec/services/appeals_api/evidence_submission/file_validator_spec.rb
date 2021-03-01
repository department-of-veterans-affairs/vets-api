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
        expect(described_class.new(valid_pdf).call).to match({ status: "validated", detail: "expected_10182_extra.pdf validated" })
      end
    end

    context 'when unsupported file type uploaded' do
      it 'returns error data when non-pdf file type' do
        expect(described_class.new(non_pdf).call).to match({ status: "error", detail: "test_incorrect_type.docx must be in PDF format" })
      end

      it 'returns error data if pdf extension but wrong type' do
        expect(described_class.new(pretend_pdf).call).to match({ status: "error", detail: "test_fake_pdf.pdf must be in PDF format" })
      end
    end

    context 'when page dimensions are too large' do
      it 'returns error data' do
        expect(described_class.new(oversize_pdf).call).to match({ status: "error", detail: "oversize_11x17.pdf exceeds the maximum page dimensions of {:width=>11, :height=>11}" })
      end
    end

    context 'when file size is too large' do
      before { allow_any_instance_of(described_class).to receive(:valid_file_size?).and_return(false) }

      it 'returns error data' do
        expect(described_class.new(valid_pdf).call).to match({ status: "error", detail: "expected_10182_extra.pdf exceeds the max-file-size of 100 MB" })
      end
    end
  end
end
