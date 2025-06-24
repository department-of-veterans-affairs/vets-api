# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va2210215a'

describe PdfFill::Forms::Va2210215a do
  let(:form_data) do
    {
      'institutionDetails' => {
        'institutionName' => 'Test University',
        'facilityCode' => '12345678',
        'termStartDate' => '2024-01-15',
        'dateOfCalculations' => '2024-01-01'
      },
      'certifyingOfficial' => {
        'first' => 'John',
        'last' => 'Doe',
        'title' => 'Registrar'
      },
      'programs' => [
        {
          'programName' => 'Computer Science',
          'studentsEnrolled' => '100',
          'supportedStudents' => '25',
          'fte' => {
            'supported' => '20',
            'nonSupported' => '80',
            'totalFTE' => '95',
            'supportedPercentageFTE' => '25'
          }
        },
        {
          'programName' => 'Engineering',
          'studentsEnrolled' => '150',
          'supportedStudents' => '30',
          'fte' => {
            'supported' => '25',
            'nonSupported' => '125',
            'totalFTE' => '98',
            'supportedPercentageFTE' => '20'
          }
        }
      ]
    }
  end

  let(:new_form_class) do
    described_class.new(form_data)
  end

  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end

  describe '#merge_fields' do
    context 'with basic form data' do
      it 'merges the right fields' do
        result = new_form_class.merge_fields

        expect(result['certifyingOfficial']['fullName']).to eq('John Doe')
        expect(result['programs'][0]['programDateOfCalculation']).to eq('2024-01-01')
        expect(result['programs'][0]['fte']['supportedPercentageFTE']).to eq('25%')
        expect(result['pageNumber']).to eq('Page 1 of 1')
        expect(result['totalPages']).to eq('1')
      end

      it 'does not modify the original form data' do
        original_data = form_data.dup
        new_form_class.merge_fields
        expect(form_data).to eq(original_data)
      end
    end

    context 'with page numbering options' do
      it 'handles custom page numbering' do
        result = new_form_class.merge_fields(page_number: 2, total_pages: 3)

        expect(result['pageNumber']).to eq('Page 2 of 3')
        expect(result['totalPages']).to eq('3')
      end

      it 'defaults to page 1 of 1 when no options provided' do
        result = new_form_class.merge_fields

        expect(result['pageNumber']).to eq('Page 1 of 1')
        expect(result['totalPages']).to eq('1')
      end
    end

    context 'with missing certifying official data' do
      let(:form_data_no_official) do
        form_data.tap { |data| data.delete('certifyingOfficial') }
      end

      let(:form_class_no_official) do
        described_class.new(form_data_no_official)
      end

      it 'handles missing certifying official gracefully' do
        result = form_class_no_official.merge_fields
        expect(result['certifyingOfficial']).to be_nil
      end
    end

    context 'with partial certifying official data' do
      let(:form_data_partial_official) do
        form_data.tap do |data|
          data['certifyingOfficial'] = { 'first' => 'John' }
        end
      end

      let(:form_class_partial_official) do
        described_class.new(form_data_partial_official)
      end

      it 'handles partial certifying official data' do
        result = form_class_partial_official.merge_fields
        expect(result['certifyingOfficial']['fullName']).to be_nil
      end
    end

    context 'with missing programs' do
      let(:form_data_no_programs) do
        form_data.tap { |data| data.delete('programs') }
      end

      let(:form_class_no_programs) do
        described_class.new(form_data_no_programs)
      end

      it 'handles missing programs gracefully' do
        result = form_class_no_programs.merge_fields
        expect(result['programs']).to be_nil
      end
    end

    context 'with missing institution details' do
      let(:form_data_no_institution) do
        form_data.tap { |data| data.delete('institutionDetails') }
      end

      let(:form_class_no_institution) do
        described_class.new(form_data_no_institution)
      end

      it 'handles missing institution details gracefully' do
        result = form_class_no_institution.merge_fields
        expect(result['programs'][0]['programDateOfCalculation']).to be_nil
      end
    end

    context 'with 16 programs' do
      let(:programs_16) do
        (1..16).map do |i|
          {
            'programName' => "Program #{i}",
            'studentsEnrolled' => '100',
            'supportedStudents' => '25',
            'fte' => {
              'supported' => '20',
              'nonSupported' => '80',
              'totalFTE' => '95',
              'supportedPercentageFTE' => '25'
            }
          }
        end
      end

      let(:form_data_16) do
        form_data.tap { |data| data['programs'] = programs_16 }
      end

      let(:form_class_16) do
        described_class.new(form_data_16)
      end

      it 'processes all 16 programs correctly' do
        result = form_class_16.merge_fields
        expect(result['programs'].length).to eq(16)
        expect(result['programs'][0]['programName']).to eq('Program 1')
        expect(result['programs'][15]['programName']).to eq('Program 16')
        result['programs'].each do |program|
          expect(program['programDateOfCalculation']).to eq('2024-01-01')
          expect(program['fte']['supportedPercentageFTE']).to eq('25%')
        end
      end
    end

    context 'with programs missing FTE data' do
      let(:form_data_no_fte) do
        form_data.tap do |data|
          data['programs'][0].delete('fte')
        end
      end

      let(:form_class_no_fte) do
        described_class.new(form_data_no_fte)
      end

      it 'handles missing FTE data gracefully' do
        result = form_class_no_fte.merge_fields
        expect(result['programs'][0]['fte']).to be_nil
        expect(result['programs'][1]['fte']['supportedPercentageFTE']).to eq('20%')
      end
    end

    context 'with programs missing supportedPercentageFTE' do
      let(:form_data_no_supported_percentage) do
        form_data.tap do |data|
          data['programs'][0]['fte'].delete('supportedPercentageFTE')
        end
      end

      let(:form_class_no_supported_percentage) do
        described_class.new(form_data_no_supported_percentage)
      end

      it 'handles missing supportedPercentageFTE gracefully' do
        result = form_class_no_supported_percentage.merge_fields
        expect(result['programs'][0]['fte']['supportedPercentageFTE']).to be_nil
        expect(result['programs'][1]['fte']['supportedPercentageFTE']).to eq('20%')
      end
    end
  end

  describe 'KEY constant' do
    it 'has the correct structure' do
      expect(described_class::KEY).to have_key('institutionDetails')
      expect(described_class::KEY).to have_key('certifyingOfficial')
      expect(described_class::KEY).to have_key('programs')
      expect(described_class::KEY).to have_key('pageNumber')
      expect(described_class::KEY).to have_key('totalPages')
    end

    it 'has correct program structure' do
      programs_key = described_class::KEY['programs']
      expect(programs_key['limit']).to eq(16)
      expect(programs_key['first_key']).to eq('programName')
      expect(programs_key).to have_key('programName')
      expect(programs_key).to have_key('studentsEnrolled')
      expect(programs_key).to have_key('supportedStudents')
      expect(programs_key).to have_key('fte')
      expect(programs_key).to have_key('programDateOfCalculation')
    end

    it 'has correct page numbering fields' do
      expect(described_class::KEY['pageNumber']['key']).to eq('pageNumber')
      expect(described_class::KEY['totalPages']['key']).to eq('totalPages')
    end
  end
end 