# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'
require 'lib/pdf_fill/fill_form_examples'

RSpec.describe PdfFill::Forms::Va21p530a do
  let(:form_data) do
    JSON.parse(Rails.root.join('spec', 'fixtures', 'pdf_fill', '21P-530a', 'simple.json').read)
  end

  it_behaves_like 'a form filler', {
    form_id: '21P-530A',
    factory: :fake_saved_claim,
    input_data_fixture_dir: 'spec/fixtures/pdf_fill/21P-530a',
    output_pdf_fixture_dir: 'spec/fixtures/pdf_fill/21P-530a',
    test_data_types: %w[simple maximal],
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

    it 'replicates SSN on page 2' do
      merged = form.merge_fields

      expect(merged['veteranInformation']['ssnPage2']).to eq(
        'first' => '123',
        'second' => '45',
        'third' => '6789'
      )
    end

    it 'formats date of birth correctly' do
      merged = form.merge_fields

      expect(merged['veteranInformation']['dateOfBirth']).to eq(
        'month' => '01',
        'day' => '01',
        'year' => '1950'
      )
    end

    it 'formats date of death correctly' do
      merged = form.merge_fields

      expect(merged['veteranInformation']['dateOfDeath']).to eq(
        'month' => '01',
        'day' => '15',
        'year' => '2024'
      )
    end

    it 'combines place of birth' do
      merged = form.merge_fields

      expect(merged['veteranInformation']['placeOfBirth']).to eq('Kansas City, MO')
    end

    it 'formats service period dates' do
      merged = form.merge_fields

      expect(merged['veteranServicePeriods']['periods'][0]['dateEnteredService']).to eq('06/01/1968')
      expect(merged['veteranServicePeriods']['periods'][0]['dateLeftService']).to eq('05/31/1972')
    end

    it 'formats date of burial as MM/DD/YYYY' do
      merged = form.merge_fields

      expect(merged['burialInformation']['dateOfBurial']).to eq('01/18/2024')
    end

    it 'splits postal code' do
      merged = form.merge_fields

      addr = merged['burialInformation']['recipientOrganization']['address']
      expect(addr['postalCode']).to eq('64037')
      expect(addr['postalCodeExtension']).to eq('1234')
    end

    it 'preserves certification signature text' do
      merged = form.merge_fields

      expect(merged['certification']['signature']).to eq('John M. Smith')
    end

    context 'with multiple service periods' do
      before do
        form_data['veteranServicePeriods']['periods'] = [
          {
            'serviceBranch' => 'Army',
            'dateEnteredService' => '1968-06-01',
            'placeEnteredService' => 'Fort Benning, GA',
            'rankAtSeparation' => 'Sergeant',
            'dateLeftService' => '1972-05-31',
            'placeLeftService' => 'Fort Hood, TX'
          },
          {
            'serviceBranch' => 'Navy',
            'dateEnteredService' => '1980-01-01',
            'placeEnteredService' => 'San Diego, CA',
            'rankAtSeparation' => 'Petty Officer',
            'dateLeftService' => '1985-12-31',
            'placeLeftService' => 'Norfolk, VA'
          }
        ]
      end

      it 'handles multiple service periods' do
        merged = form.merge_fields

        expect(merged['veteranServicePeriods']['periods'].length).to eq(2)
        expect(merged['veteranServicePeriods']['periods'][0]['serviceBranch']).to eq('Army')
        expect(merged['veteranServicePeriods']['periods'][1]['serviceBranch']).to eq('Navy')
      end
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
          x: described_class::SIGNATURE_X,
          y: described_class::SIGNATURE_Y,
          page_number: described_class::SIGNATURE_PAGE,
          size: described_class::SIGNATURE_SIZE,
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

    context 'when certification key is missing' do
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
          'Form21p530a: Error stamping signature',
          hash_including(error: 'PDF stamping failed')
        )
      end
    end
  end

  describe 'PDF generation' do
    it 'generates a PDF successfully', :skip_mvi do
      file_path = PdfFill::Filler.fill_ancillary_form(
        form_data,
        'test-123',
        '21P-530A'
      )

      expect(File.exist?(file_path)).to be true
      expect(file_path).to include('21P-530A')

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
        '21P-530A'
      )

      expect(File.exist?(file_path)).to be true

      # Cleanup
      FileUtils.rm_f(file_path)
    end
  end
end
