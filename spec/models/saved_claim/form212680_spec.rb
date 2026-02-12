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

  describe '#metadata_for_benefits_intake' do
    let(:parsed_form_data) do
      {
        'veteranInformation' => {
          'fullName' => { 'first' => 'John', 'last' => 'Doe' },
          'ssn' => '123456789',
          'vaFileNumber' => '987654321'
        },
        'claimantInformation' => {
          'address' => { 'postalCode' => '627011234' }
        }
      }
    end

    before do
      allow(claim).to receive(:parsed_form).and_return(parsed_form_data)
    end

    it 'returns correct metadata hash including docType' do
      metadata = claim.metadata_for_benefits_intake

      expect(metadata).to eq(
        veteranFirstName: 'John',
        veteranLastName: 'Doe',
        fileNumber: '987654321',
        zipCode: '62701',
        businessLine: 'PMC',
        docType: 'StructuredData:21-2680'
      )
    end

    it 'includes docType with correct format' do
      metadata = claim.metadata_for_benefits_intake
      expect(metadata[:docType]).to eq('StructuredData:21-2680')
    end

    it 'falls back to SSN when vaFileNumber is missing' do
      parsed_form_data['veteranInformation'].delete('vaFileNumber')
      metadata = claim.metadata_for_benefits_intake

      expect(metadata[:fileNumber]).to eq('123456789')
    end

    it 'extracts first 5 digits of zip code' do
      metadata = claim.metadata_for_benefits_intake
      expect(metadata[:zipCode]).to eq('62701')
    end
  end

  describe '#to_ibm' do
    let(:ibm_data) { claim.to_ibm }

    it 'returns a hash with all required fields' do
      expect(ibm_data).to be_a(Hash)
      expect(ibm_data).not_to be_empty
    end

    context 'veteran identification fields (Boxes 1-5)' do
      it 'includes veteran name fields' do
        expect(ibm_data['VETERAN_FIRST_NAME']).to eq('John')
        expect(ibm_data['VETERAN_MIDDLE_INITIAL']).to eq('A')
        expect(ibm_data['VETERAN_LAST_NAME']).to eq('Doe')
      end

      it 'includes veteran SSN and file numbers' do
        expect(ibm_data['VETERAN_SSN']).to eq('123456789')
        expect(ibm_data['VA_FILE_NUMBER']).to eq('987654321')
        expect(ibm_data['VETERAN_SERVICE_NUMBER']).to eq('A123456')
      end

      it 'includes veteran DOB with slashes' do
        expect(ibm_data['VETERAN_DOB']).to eq('02/03/1951')
      end
    end

    context 'claimant identification fields (Boxes 6-12)' do
      it 'includes claimant name fields' do
        expect(ibm_data['CLAIMANT_FIRST_NAME']).to eq('Jane')
        expect(ibm_data['CLAIMANT_MIDDLE_INITIAL']).to eq('c')
        expect(ibm_data['CLAIMANT_LAST_NAME']).to eq('Dough')
      end

      it 'includes claimant SSN and DOB' do
        expect(ibm_data['CLAIMANT_SSN']).to eq('987654321')
        expect(ibm_data['CLAIMANT_DOB']).to eq('01/01/1950')
      end

      it 'includes claimant contact information' do
        expect(ibm_data['PHONE_NUMBER']).to eq('5551234567')
        expect(ibm_data['EMAIL']).to eq('test@va.gov')
      end

      it 'includes claimant address fields' do
        expect(ibm_data['CLAIMANT_ADDRESS_LINE1']).to eq('123 Main St')
        expect(ibm_data['CLAIMANT_ADDRESS_LINE2']).to eq('Apt 4')
        expect(ibm_data['CLAIMANT_ADDRESS_CITY']).to eq('Springfield')
        expect(ibm_data['CLAIMANT_ADDRESS_STATE']).to eq('IL')
        expect(ibm_data['CLAIMANT_ADDRESS_COUNTRY']).to eq('USA')
        expect(ibm_data['CLAIMANT_ADDRESS_ZIP5']).to eq('62701')
      end

      it 'includes relationship checkboxes' do
        expect(ibm_data['SELF']).to be(true)
        expect(ibm_data['SPOUSE']).to be(false)
        expect(ibm_data['PARENT']).to be(false)
        expect(ibm_data['CHILD']).to be(false)
      end
    end

    context 'benefit information fields (Box 13)' do
      it 'includes benefit selection checkboxes' do
        expect(ibm_data['CB_SMC']).to be(true)
        expect(ibm_data['CB_SMP']).to be(false)
      end
    end

    context 'hospitalization fields (Box 14)' do
      it 'includes hospitalization status' do
        expect(ibm_data['CL_HOSPITALIZED_YES']).to be(false)
        expect(ibm_data['CL_HOSPITALIZED_NO']).to be(true)
      end

      it 'includes hospital details' do
        expect(ibm_data['ADMISSION_DATE']).to eq('01/01/2023')
        expect(ibm_data['HOSPITAL_NAME']).to eq('VA Medical Center')
        expect(ibm_data['HOSPITAL_ADDRESS']).to include('123 Main St')
      end
    end

    context 'signature fields (Box 15)' do
      it 'includes claimant signature and date' do
        expect(ibm_data['CLAIMANT_SIGNATURE']).to eq('John A Doe')
        expect(ibm_data['CLAIMANT_SIGNATURE_DATE']).to eq('10/20/2025')
      end

      it 'includes duplicate veteran SSN fields for pages 2-4' do
        expect(ibm_data['VETERAN_SSN_1']).to eq('123456789')
        expect(ibm_data['VETERAN_SSN_2']).to eq('123456789')
        expect(ibm_data['VETERAN_SSN_3']).to eq('123456789')
      end
    end

    context 'form metadata fields' do
      it 'includes form type on all pages' do
        expect(ibm_data['FORM_TYPE']).to eq('21-2680')
        expect(ibm_data['FORM_TYPE_1']).to eq('21-2680')
        expect(ibm_data['FORM_TYPE_2']).to eq('21-2680')
        expect(ibm_data['FORM_TYPE_3']).to eq('21-2680')
      end
    end
  end
end
