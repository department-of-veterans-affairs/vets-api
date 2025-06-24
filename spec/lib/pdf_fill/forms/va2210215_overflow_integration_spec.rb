# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

describe 'PdfFill::Filler 22-10215 Overflow Integration' do
  let(:base_form_data) do
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
      'statementOfTruthSignature' => 'John Doe',
      'dateSigned' => '2024-01-01'
    }
  end

  def create_programs(count)
    (1..count).map do |i|
      {
        'programName' => "Program #{i}",
        'studentsEnrolled' => (100 + i).to_s,
        'supportedStudents' => (25 + i).to_s,
        'fte' => {
          'supported' => (20 + i).to_s,
          'nonSupported' => (80 + i).to_s,
          'totalFTE' => (95 + i).to_s,
          'supportedPercentageFTE' => (25 + i).to_s
        }
      }
    end
  end

  def form_data_with_programs(program_count)
    base_form_data.merge('programs' => create_programs(program_count))
  end

  describe 'with 16 or fewer programs' do
    [1, 8, 16].each do |program_count|
      context "with #{program_count} programs" do
        let(:form_data) { form_data_with_programs(program_count) }

        it 'uses regular form processing without continuation sheets' do
          expect(PdfFill::Filler).not_to receive(:process_form_with_continuation_sheets)
          
          result_path = PdfFill::Filler.fill_ancillary_form(form_data, 'test_id', '22-10215')
          
          expect(result_path).to include('22-10215_test_id.pdf')
          expect(File.exist?(result_path)).to be true
          
          File.delete(result_path) if File.exist?(result_path)
        end
      end
    end
  end

  describe 'with more than 16 programs' do
    [17, 32, 35, 50].each do |program_count|
      context "with #{program_count} programs" do
        let(:form_data) { form_data_with_programs(program_count) }
        let(:expected_pages) { 1 + ((program_count - 16).to_f / 16).ceil }

        it 'uses continuation sheet processing' do
          expect(PdfFill::Filler).to receive(:process_form_with_continuation_sheets).and_call_original
          
          result_path = PdfFill::Filler.fill_ancillary_form(form_data, 'test_id', '22-10215')
          
          expect(result_path).to include('22-10215_test_id.pdf')
          expect(File.exist?(result_path)).to be true
          byebug
          File.delete(result_path) if File.exist?(result_path)
        end

        it 'generates the correct number of pages' do
          allow(Rails.logger).to receive(:info)
          
          result_path = PdfFill::Filler.fill_ancillary_form(form_data, 'test_id', '22-10215')
          
          expect(Rails.logger).to have_received(:info).with(
            'PdfFill done with continuation sheets',
            hash_including(
              form_id: '22-10215',
              file_name_extension: 'test_id',
              total_pages: expected_pages,
              total_programs: program_count
            )
          )
          
          File.delete(result_path) if File.exist?(result_path)
        end
      end
    end
  end

  describe 'continuation sheet generation' do
    let(:form_data) { form_data_with_programs(35) } # This will need 3 pages total

    it 'creates proper continuation forms with correct data distribution' do
      # Mock the individual form generation to verify data distribution
      main_form_data = nil
      continuation_1_data = nil
      continuation_2_data = nil

      allow(PdfFill::Forms::Va2210215).to receive(:new) do |data|
        main_form_data = data
        instance_double(PdfFill::Forms::Va2210215, merge_fields: data)
      end

      allow(PdfFill::Forms::Va2210215a).to receive(:new) do |data|
        if continuation_1_data.nil?
          continuation_1_data = data
        else
          continuation_2_data = data
        end
        instance_double(PdfFill::Forms::Va2210215a, merge_fields: data)
      end

      # Mock PDF operations to avoid actual file operations
      allow(PdfFill::Filler::PDF_FORMS).to receive(:fill_form)
      allow(PdfFill::Filler::PDF_FORMS).to receive(:cat)
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:delete)

      PdfFill::Filler.send(:process_form_with_continuation_sheets, 
                          '22-10215', form_data, PdfFill::Forms::Va2210215, 'test_id', {})

      # Verify main form gets first 16 programs
      expect(main_form_data['programs'].length).to eq(35) # Original data passed through
      
      # Verify first continuation gets programs 17-32
      expect(continuation_1_data['programs'].length).to eq(16)
      expect(continuation_1_data['programs'][0]['programName']).to eq('Program 17')
      expect(continuation_1_data['programs'][15]['programName']).to eq('Program 32')
      
      # Verify second continuation gets programs 33-35
      expect(continuation_2_data['programs'].length).to eq(3)
      expect(continuation_2_data['programs'][0]['programName']).to eq('Program 33')
      expect(continuation_2_data['programs'][2]['programName']).to eq('Program 35')
    end
  end

  describe 'error handling' do
    let(:form_data) { form_data_with_programs(20) }

    it 'cleans up temporary files even when errors occur' do
      temp_files = []
      
      allow(PdfFill::Filler::PDF_FORMS).to receive(:fill_form) do |template, file_path, *args|
        temp_files << file_path
        # Simulate the first call succeeding, second call failing
        raise StandardError, 'PDF generation failed' if temp_files.length > 1
      end
      
      allow(File).to receive(:exist?) { |path| temp_files.include?(path) }
      expect(File).to receive(:delete).with(temp_files[0])

      expect do
        PdfFill::Filler.send(:process_form_with_continuation_sheets, 
                            '22-10215', form_data, PdfFill::Forms::Va2210215, 'test_id', {})
      end.to raise_error(StandardError, 'PDF generation failed')
    end
  end

  describe 'form class validation' do
    let(:form_data) { form_data_with_programs(17) }

    it 'uses the correct form classes' do
      expect(PdfFill::Filler::FORM_CLASSES['22-10215']).to eq(PdfFill::Forms::Va2210215)
      expect(PdfFill::Filler::FORM_CLASSES['22-10215a']).to eq(PdfFill::Forms::Va2210215a)
    end

    it 'generates main form with Va2210215 class' do
      expect(PdfFill::Forms::Va2210215).to receive(:new).and_call_original
      
      # Mock the rest to avoid file operations
      allow(PdfFill::Filler::PDF_FORMS).to receive(:fill_form)
      allow(PdfFill::Filler::PDF_FORMS).to receive(:cat)
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:delete)

      PdfFill::Filler.send(:process_form_with_continuation_sheets, 
                          '22-10215', form_data, PdfFill::Forms::Va2210215, 'test_id', {})
    end

    it 'generates continuation forms with Va2210215a class' do
      expect(PdfFill::Forms::Va2210215a).to receive(:new).and_call_original
      
      # Mock the rest to avoid file operations
      allow(PdfFill::Filler::PDF_FORMS).to receive(:fill_form)
      allow(PdfFill::Filler::PDF_FORMS).to receive(:cat)
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:delete)

      PdfFill::Filler.send(:process_form_with_continuation_sheets, 
                          '22-10215', form_data, PdfFill::Forms::Va2210215, 'test_id', {})
    end
  end
end 