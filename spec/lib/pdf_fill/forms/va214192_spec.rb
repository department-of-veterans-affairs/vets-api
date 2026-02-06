# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'
require 'lib/pdf_fill/fill_form_examples'

RSpec.describe PdfFill::Forms::Va214192 do
  let(:form_data) do
    JSON.parse(Rails.root.join('spec', 'fixtures', 'pdf_fill', '21-4192', 'simple.json').read)
  end

  it_behaves_like 'a form filler', {
    form_id: '21-4192',
    factory: :fake_saved_claim,
    input_data_fixture_dir: 'spec/fixtures/pdf_fill/21-4192',
    output_pdf_fixture_dir: 'spec/fixtures/pdf_fill/21-4192',
    test_data_types: %w[simple kitchen_sink maximal_length],
    fill_options: {
      sign: false
    }
  }

  describe '#merge_fields' do
    let(:form) { described_class.new(form_data) }

    it 'splits SSN into three parts' do
      merged = form.merge_fields

      expect(merged['veteranInformation']['ssn']).to eq(
        'first' => '123',
        'second' => '45',
        'third' => '6789'
      )
    end

    it 'formats dates correctly' do
      merged = form.merge_fields

      expect(merged['veteranInformation']['dateOfBirth']).to eq(
        'month' => '01',
        'day' => '01',
        'year' => '1980'
      )
    end

    it 'combines employer name and address' do
      merged = form.merge_fields

      expect(merged['employmentInformation']['employerNameAndAddress']).to include('Acme Corporation')
      expect(merged['employmentInformation']['employerNameAndAddress']).to include('456 Business Ave')
      expect(merged['employmentInformation']['employerNameAndAddress']).to include('Commerce City, CA 54321')
    end

    it 'formats dollar amounts correctly' do
      merged = form.merge_fields

      expect(merged['employmentInformation']['amountEarnedLast12MonthsOfEmployment']).to eq(
        'thousands' => '095',
        'hundreds' => '000',
        'cents' => '00'
      )
    end

    it 'converts booleans to YES/NO' do
      merged = form.merge_fields

      expect(merged['employmentInformation']['lumpSumPaymentMade']).to eq('YES')
      expect(merged['militaryDutyStatus']['veteranDisabilitiesPreventMilitaryDuties']).to eq('YES')
      expect(merged['benefitEntitlementPayments']['sickRetirementOtherBenefits']).to eq('YES')
    end
  end

  describe 'PDF generation' do
    it 'generates a PDF successfully', :skip_mvi do
      file_path = PdfFill::Filler.fill_ancillary_form(
        form_data,
        'test-123',
        '21-4192'
      )

      expect(File.exist?(file_path)).to be true
      expect(file_path).to include('21-4192')

      # Verify it's a valid PDF
      pdf_content = File.read(file_path)
      expect(pdf_content).to start_with('%PDF')

      # Cleanup
      FileUtils.rm_f(file_path)
    end

    it 'fills veteran name fields', :skip_mvi do
      file_path = PdfFill::Filler.fill_ancillary_form(
        form_data,
        'test-name',
        '21-4192'
      )

      expect(File.exist?(file_path)).to be true

      # Cleanup
      FileUtils.rm_f(file_path)
    end
  end

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
          'certification' => {
            'signature' => 'John H. Doe'
          }
        }
      end

      it 'stamps the signature onto the PDF' do
        expect(datestamp_instance).to receive(:run).with(
          text: 'John H. Doe',
          x: PdfFill::Forms::Va214192::SIGNATURE_X,
          y: PdfFill::Forms::Va214192::SIGNATURE_Y,
          page_number: PdfFill::Forms::Va214192::SIGNATURE_PAGE,
          size: PdfFill::Forms::Va214192::SIGNATURE_SIZE,
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
          'certification' => {
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
          'certification' => {}
        }
      end

      it 'returns original path without stamping' do
        expect(datestamp_instance).not_to receive(:run)

        result = described_class.stamp_signature(pdf_path, form_data_nil_sig)
        expect(result).to eq(pdf_path)
      end
    end

    context 'when signature is whitespace only' do
      let(:form_data_whitespace_sig) do
        {
          'certification' => {
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
          'certification' => {
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
          'Form214192: Error stamping signature',
          hash_including(error: 'PDF stamping failed')
        )
      end
    end
  end
end
