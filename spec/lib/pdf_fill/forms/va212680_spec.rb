# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va212680 do
  it_behaves_like 'a form filler', {
    form_id: '21-2680',
    factory: :form212680Simple,
    use_vets_json_schema: true,
    output_pdf_fixture_dir: 'spec/fixtures/pdf_fill/21-2680',
    test_data_types: %w[simple],
    run_at: '2025-10-24T18:48:27Z'
  }

  describe '.stamp_signature' do
    let(:pdf_path) { '/tmp/test_form.pdf' }
    let(:stamped_path) { '/tmp/test_form_stamped.pdf' }
    let(:datestamp_instance) { instance_double(PDFUtilities::DatestampPdf) }

    before do
      allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path).and_return(datestamp_instance)
    end

    context 'when signature is present' do
      let(:form_data_with_sig) do
        {
          'veteranSignature' => {
            'signature' => 'John H. Doe'
          }
        }
      end

      it 'stamps the signature onto the PDF' do
        expect(datestamp_instance).to receive(:run).with(
          text: 'John H. Doe',
          x: PdfFill::Forms::Va212680::SIGNATURE_X,
          y: PdfFill::Forms::Va212680::SIGNATURE_Y,
          page_number: PdfFill::Forms::Va212680::SIGNATURE_PAGE,
          size: PdfFill::Forms::Va212680::SIGNATURE_SIZE,
          text_only: true,
          timestamp: '',
          template: pdf_path,
          multistamp: true
        ).and_return(stamped_path)

        result = described_class.stamp_signature(pdf_path, form_data_with_sig)
        expect(result).to eq(stamped_path)
      end
    end

    context 'when signature is blank' do
      let(:form_data_no_sig) do
        {
          'veteranSignature' => {
            'signature' => ''
          }
        }
      end

      it 'returns original path without stamping' do
        expect(datestamp_instance).not_to receive(:run)

        result = described_class.stamp_signature(pdf_path, form_data_no_sig)
        expect(result).to eq(pdf_path)
      end
    end

    context 'when signature is nil' do
      let(:form_data_nil_sig) do
        {
          'veteranSignature' => {}
        }
      end

      it 'returns original path without stamping' do
        expect(datestamp_instance).not_to receive(:run)

        result = described_class.stamp_signature(pdf_path, form_data_nil_sig)
        expect(result).to eq(pdf_path)
      end
    end

    context 'when veteranSignature key is missing' do
      let(:form_data_missing_key) { {} }

      it 'returns original path without stamping' do
        expect(datestamp_instance).not_to receive(:run)

        result = described_class.stamp_signature(pdf_path, form_data_missing_key)
        expect(result).to eq(pdf_path)
      end
    end

    context 'when signature is whitespace only' do
      let(:form_data_whitespace_sig) do
        {
          'veteranSignature' => {
            'signature' => '   '
          }
        }
      end

      it 'returns original path without stamping' do
        expect(datestamp_instance).not_to receive(:run)

        result = described_class.stamp_signature(pdf_path, form_data_whitespace_sig)
        expect(result).to eq(pdf_path)
      end
    end

    context 'when stamping fails' do
      let(:form_data_with_sig) do
        {
          'veteranSignature' => {
            'signature' => 'John Doe'
          }
        }
      end

      it 'logs error and returns original path' do
        allow(datestamp_instance).to receive(:run).and_raise(StandardError, 'PDF stamping failed')
        allow(Rails.logger).to receive(:error)

        result = described_class.stamp_signature(pdf_path, form_data_with_sig)

        expect(result).to eq(pdf_path)
        expect(Rails.logger).to have_received(:error).with(
          'Form212680: Error stamping signature',
          hash_including(error: 'PDF stamping failed')
        )
      end
    end
  end
end
