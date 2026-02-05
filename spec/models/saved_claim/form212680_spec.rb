# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Form212680, type: :model do
  let(:claim) { build(:form212680) }

  describe 'FORM constant' do
    it 'is set to 21-2680' do
      expect(described_class::FORM).to eq('21-2680')
    end
  end

  describe '#regional_office' do
    it 'returns Pension Management Center address' do
      expect(claim.regional_office).to eq([
                                            'Department of Veterans Affairs',
                                            'Pension Management Center',
                                            'P.O. Box 5365',
                                            'Janesville, WI 53547-5365'
                                          ])
    end
  end

  describe '#business_line' do
    it 'returns PMC for Pension Management Center' do
      expect(claim.business_line).to eq('PMC')
    end
  end

  describe '#document_type' do
    it 'returns 540 for Aid and Attendance/Housebound' do
      expect(claim.document_type).to eq(540)
    end
  end

  describe '#attachment_keys' do
    it 'returns empty frozen array' do
      expect(claim.attachment_keys).to eq([])
      expect(claim.attachment_keys).to be_frozen
    end
  end

  describe '#to_pdf' do
    let(:pdf_path) { '/tmp/test_form.pdf' }
    let(:stamped_pdf_path) { '/tmp/test_form_stamped.pdf' }
    let(:parsed_form_data) do
      {
        'veteranSignature' => {
          'signature' => 'John Doe'
        }
      }
    end

    before do
      allow(PdfFill::Filler).to receive(:fill_form).and_return(pdf_path)
      allow(PdfFill::Forms::Va212680).to receive(:stamp_signature).and_return(stamped_pdf_path)
      allow(claim).to receive(:parsed_form).and_return(parsed_form_data)
    end

    it 'generates PDF and stamps the signature' do
      result = claim.to_pdf

      expect(PdfFill::Filler).to have_received(:fill_form).with(claim, nil, {})
      expect(PdfFill::Forms::Va212680).to have_received(:stamp_signature).with(pdf_path, parsed_form_data)
      expect(result).to eq(stamped_pdf_path)
    end

    it 'passes file_name to the filler' do
      claim.to_pdf('custom-file-name')

      expect(PdfFill::Filler).to have_received(:fill_form).with(claim, 'custom-file-name', {})
    end

    it 'passes fill_options to the filler' do
      fill_options = { extras_redesign: true }
      claim.to_pdf('test-id', fill_options)

      expect(PdfFill::Filler).to have_received(:fill_form).with(claim, 'test-id', fill_options)
    end

    it 'returns the stamped PDF path' do
      result = claim.to_pdf

      expect(result).to eq(stamped_pdf_path)
    end
  end

  describe '#generate_prefilled_pdf' do
    let(:pdf_path) { '/tmp/generated_form.pdf' }

    before do
      allow(claim).to receive(:to_pdf).and_return(pdf_path)
      allow(claim).to receive(:update_metadata_with_pdf_generation)
    end

    it 'generates a PDF' do
      claim.generate_prefilled_pdf

      expect(claim).to have_received(:to_pdf).with(no_args)
    end

    it 'updates metadata after PDF generation' do
      claim.generate_prefilled_pdf

      expect(claim).to have_received(:update_metadata_with_pdf_generation)
    end

    it 'returns the generated PDF path' do
      result = claim.generate_prefilled_pdf

      expect(result).to eq(pdf_path)
    end
  end

  describe '#download_instructions' do
    before do
      allow(Settings).to receive(:hostname).and_return('https://www.va.gov')
    end

    it 'returns download instructions hash' do
      instructions = claim.download_instructions

      expect(instructions[:title]).to eq('Next Steps: Get Physician to Complete Form')
      expect(instructions[:form_number]).to eq('21-2680')
      expect(instructions[:upload_url]).to eq('https://www.va.gov/upload-supporting-documents')
      expect(instructions[:steps]).to be_an(Array)
      expect(instructions[:steps].length).to eq(7)
    end

    it 'includes regional office in instructions' do
      instructions = claim.download_instructions

      expect(instructions[:regional_office]).to include('Pension Management Center')
    end
  end

  describe '#to_ibm' do
    let(:claim) { build(:form212680) }
    let(:ibm_payload) { claim.to_ibm }

    it 'returns a hash with VBA Data Dictionary fields' do
      expect(ibm_payload).to be_a(Hash)
    end

    it 'includes veteran identification fields' do
      parsed = JSON.parse(claim.form)
      vet_info = parsed['veteranInformation']

      expect(ibm_payload).to include(
        'VETERAN_FIRST_NAME' => vet_info.dig('fullName', 'first'),
        'VETERAN_LAST_NAME' => vet_info.dig('fullName', 'last'),
        'VETERAN_SSN' => vet_info['ssn']
      )
    end

    it 'includes claimant information fields when present' do
      parsed = JSON.parse(claim.form)
      next unless parsed['claimantInformation']

      claimant = parsed['claimantInformation']
      if claimant
        expect(ibm_payload).to include(
          'CLAIMANT_FIRST_NAME' => claimant.dig('fullName', 'first'),
          'CLAIMANT_LAST_NAME' => claimant.dig('fullName', 'last')
        )
      end
    end

    it 'includes form metadata' do
      expect(ibm_payload).to include('FORM_TYPE' => '2680')
    end

    it 'formats dates in MM/DD/YYYY format' do
      parsed = JSON.parse(claim.form)
      if parsed.dig('veteranInformation', 'dateOfBirth')
        dob = ibm_payload['VETERAN_DOB']
        expect(dob).to match(%r{\d{2}/\d{2}/\d{4}}) if dob.present?
      end
    end

    it 'handles checkbox values as X or nil' do
      # Checkboxes should be 'X' for true, nil for false
      hospitalized_yes = ibm_payload['CL_HOSPITALIZED_YES']
      expect([nil, 'X']).to include(hospitalized_yes) if hospitalized_yes
    end

    it 'includes physical assessment fields when present' do
      parsed = JSON.parse(claim.form)
      if parsed['physicalAssessment']
        physical = parsed['physicalAssessment']
        expect(ibm_payload.keys).to include('CLAIMANT_AGE') if physical['age']
      end
    end

    it 'includes examiner information fields when present' do
      parsed = JSON.parse(claim.form)
      if parsed['examinerInformation']
        examiner = parsed['examinerInformation']
        expect(ibm_payload).to include('EXAMINER_NAME' => examiner['examinerName']) if examiner['examinerName']
      end
    end
  end
end
