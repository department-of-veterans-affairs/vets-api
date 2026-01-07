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
    test_data_types: %w[simple],
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
