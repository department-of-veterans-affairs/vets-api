# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::Uploads::DocumentValidation do
  describe '#validate' do
    # rubocop:disable Layout/LineLength
    let(:valid_pdf) { { 'document': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/appeals_api/spec/fixtures/expected_10182_extra.pdf") } }
    let(:non_pdf) { { 'document': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/appeals_api/spec/fixtures/test_incorrect_type.docx") } }
    let(:pretend_pdf) { { 'document': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/appeals_api/spec/fixtures/test_fake_pdf.pdf") } }
    let(:oversize_pdf) { { 'document': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/appeals_api/spec/fixtures/oversize_11x17.pdf") } }

    context 'when supported file uploaded (100MB 11in x 11in PDF)' do
      it 'does not raise an error' do
        expect { described_class.new(valid_pdf).validate }.not_to raise_error
      end
    end

    context 'when unsupported file type uploaded' do
      it 'raises an error when non-pdf file type' do
        expect { described_class.new(non_pdf).validate }.to raise_error AppealsApi::Uploads::DocumentValidation::UploadValidationError
      end

      it 'raises an exception if pdf extension but wrong type' do
        expect { described_class.new(pretend_pdf).validate }.to raise_error AppealsApi::Uploads::DocumentValidation::UploadValidationError
      end
    end

    context 'when page dimensions are too large' do
      it 'raises and error' do
        expect { described_class.new(oversize_pdf).validate }.to raise_error AppealsApi::Uploads::DocumentValidation::UploadValidationError
      end
    end

    context 'when file size is too large' do
      before { allow_any_instance_of(described_class).to receive(:valid_file_size?).and_return(false) }

      it 'raises and error' do
        expect { described_class.new(valid_pdf).validate }.to raise_error AppealsApi::Uploads::DocumentValidation::UploadValidationError
      end
    end

    # context 'when pdf password protected' do
    # end

    # context 'when pdf encrypted' do
    # end
    # rubocop:enable Layout/LineLength
  end
end
