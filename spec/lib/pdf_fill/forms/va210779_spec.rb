# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va210779 do
  it_behaves_like 'a form filler', {
    form_id: '21-0779',
    factory: :va210779_countries,
    use_vets_json_schema: true,
    test_data_types: %w[simple],
    run_at: '2025-10-24T18:48:27Z'
  }

  describe '.stamp_signature' do
    let(:pdf_path) { 'tmp/test_form.pdf' }
    let(:signature_text) { 'John Doe' }
    let(:form_data) do
      {
        'generalInformation' => {
          'signature' => signature_text,
          'nursingOfficialName' => 'Jane Smith'
        }
      }
    end

    before do
      allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(
        double(run: 'tmp/stamped.pdf')
      )
    end

    context 'with signature in generalInformation.signature' do
      it 'stamps the signature on the PDF' do
        expect(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path).and_return(
          double(run: 'tmp/stamped.pdf')
        )

        result = described_class.stamp_signature(pdf_path, form_data)
        expect(result).to eq('tmp/stamped.pdf')
      end

      it 'calls DatestampPdf with correct parameters' do
        datestamp_double = instance_double(PDFUtilities::DatestampPdf)
        allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path).and_return(datestamp_double)

        expect(datestamp_double).to receive(:run).with(
          text: signature_text,
          x: described_class::SIGNATURE_X,
          y: described_class::SIGNATURE_Y,
          page_number: described_class::SIGNATURE_PAGE,
          size: described_class::SIGNATURE_SIZE,
          text_only: true,
          timestamp: '',
          template: pdf_path,
          multistamp: true
        ).and_return('tmp/stamped.pdf')

        described_class.stamp_signature(pdf_path, form_data)
      end
    end

    context 'with no signature data' do
      let(:form_data) { { 'generalInformation' => {} } }

      it 'returns the original PDF path without stamping' do
        expect(PDFUtilities::DatestampPdf).not_to receive(:new)
        result = described_class.stamp_signature(pdf_path, form_data)
        expect(result).to eq(pdf_path)
      end
    end

    context 'with blank signature' do
      let(:form_data) do
        { 'generalInformation' => { 'signature' => '   ' } }
      end

      it 'returns the original PDF path without stamping' do
        expect(PDFUtilities::DatestampPdf).not_to receive(:new)
        result = described_class.stamp_signature(pdf_path, form_data)
        expect(result).to eq(pdf_path)
      end
    end

    context 'when stamping raises an error' do
      let(:error_message) { 'PDF stamping failed' }

      before do
        allow(PDFUtilities::DatestampPdf).to receive(:new).and_raise(StandardError, error_message)
      end

      it 'logs the error and returns the original PDF path' do
        expect(Rails.logger).to receive(:error).with(
          'Form210779: Error stamping signature',
          hash_including(error: error_message)
        )

        result = described_class.stamp_signature(pdf_path, form_data)
        expect(result).to eq(pdf_path)
      end
    end
  end
end
