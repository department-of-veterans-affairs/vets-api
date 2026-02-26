# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Form210779, type: :model do
  let(:valid_form_data) { build(:va210779).form }
  let(:invalid_form_data) { build(:va210779_invalid).form }
  let(:claim) { described_class.new(form:) }
  let(:form) { valid_form_data }

  describe 'validations' do
    context 'with valid form data' do
      it 'validates successfully' do
        expect(claim).to be_valid
      end
    end

    context 'with invalid form data' do
      let(:form) { invalid_form_data }

      it 'fails validation' do
        expect(claim).to be_invalid
      end
    end
  end

  describe '#send_confirmation_email' do
    it 'does not send email (MVP does not include email)' do
      expect(VANotify::EmailJob).not_to receive(:perform_async)
      claim.send_confirmation_email
    end
  end

  describe '#business_line' do
    it 'returns CMP for compensation claims' do
      expect(claim.business_line).to eq('CMP')
    end
  end

  describe '#document_type' do
    it 'returns 222 for nursing home' do
      expect(claim.document_type).to eq(222)
    end
  end

  describe '#regional_office' do
    it 'returns empty array' do
      expect(claim.regional_office).to eq([])
    end
  end

  describe '#process_attachments!' do
    it 'queues Lighthouse submission job without attachments' do
      expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async).with(claim.id)
      claim.process_attachments!
    end
  end

  describe '#to_pdf' do
    let(:saved_claim) { create(:va210779) }
    let(:pdf_path) { 'tmp/pdfs/21-0779_test.pdf' }
    let(:stamped_pdf_path) { 'tmp/pdfs/21-0779_test_stamped.pdf' }

    before do
      allow(PdfFill::Filler).to receive(:fill_form).and_return(pdf_path)
      allow(PdfFill::Forms::Va210779).to receive(:stamp_signature).and_return(stamped_pdf_path)
    end

    it 'generates the PDF using PdfFill::Filler' do
      expect(PdfFill::Filler).to receive(:fill_form).with(saved_claim, nil, {}).and_return(pdf_path)
      saved_claim.to_pdf
    end

    it 'calls stamp_signature with the filled PDF and parsed form data' do
      expect(PdfFill::Forms::Va210779).to receive(:stamp_signature).with(
        pdf_path,
        saved_claim.parsed_form
      ).and_return(stamped_pdf_path)

      saved_claim.to_pdf
    end

    it 'returns the stamped PDF path' do
      result = saved_claim.to_pdf
      expect(result).to eq(stamped_pdf_path)
    end

    it 'passes through file_name and fill_options to PdfFill::Filler' do
      file_name = 'custom_name.pdf'
      fill_options = { flatten: true }

      expect(PdfFill::Filler).to receive(:fill_form).with(
        saved_claim,
        file_name,
        fill_options
      ).and_return(pdf_path)

      saved_claim.to_pdf(file_name, fill_options)
    end
  end

  describe '#metadata_for_benefits_intake' do
    it 'includes docType with StructuredData: prefix' do
      metadata = claim.metadata_for_benefits_intake
      expect(metadata[:docType]).to eq('StructuredData:21-0779')
    end

    it 'includes all required metadata fields' do
      metadata = claim.metadata_for_benefits_intake
      expect(metadata).to include(
        veteranFirstName: 'John',
        veteranLastName: 'Doe',
        zipCode: '62701',
        businessLine: 'CMP',
        docType: 'StructuredData:21-0779'
      )
    end
  end

  describe '#to_ibm' do
    let(:claim) { create(:va210779) }

    it 'returns a hash with VBA Data Dictionary fields' do
      ibm_payload = claim.to_ibm
      expect(ibm_payload).to be_a(Hash)
    end

    it 'includes veteran information fields' do
      ibm_payload = claim.to_ibm
      expect(ibm_payload).to include(
        'VETERAN_FIRST_NAME',
        'VETERAN_LAST_NAME',
        'VETERAN_SSN'
      )
    end

    it 'includes claimant information fields' do
      ibm_payload = claim.to_ibm
      expect(ibm_payload).to include(
        'CLAIMANT_FIRST_NAME',
        'CLAIMANT_LAST_NAME'
      )
    end

    it 'includes nursing home facility fields' do
      ibm_payload = claim.to_ibm
      expect(ibm_payload).to include(
        'NAME_FACILITY_C',
        'FACILITY_ADDRESS_LINE1_C'
      )
    end

    it 'includes form metadata and system fields' do
      ibm_payload = claim.to_ibm
      expect(ibm_payload['FORM_TYPE']).to eq('21-0779')
      expect(ibm_payload['FORM_TYPE_1']).to eq('21-0779')
      expect(ibm_payload['FLASH_TEXT']).to be_nil
      expect(ibm_payload['CB_VA_STAMP']).to be_nil
    end

    it 'returns complete VBA Data Dictionary payload with all 40 required fields' do
      ibm_payload = claim.to_ibm

      # NOTE: Currently returns 41 fields including VETERAN_NAME.
      # Will be fixed to 40 when VETERAN_NAME removal PR merges
      expect(ibm_payload.keys.length).to eq(40)

      # Veteran fields (6 - excludes VETERAN_NAME per VBA Data Dictionary)
      expect(ibm_payload).to include(
        'VETERAN_FIRST_NAME' => 'John',
        'VETERAN_MIDDLE_INITIAL' => 'A',
        'VETERAN_LAST_NAME' => 'Doe',
        'VETERAN_DOB' => '01/01/1990',
        'VETERAN_SSN' => '123456789',
        'VA_FILE_NUMBER' => '987654321'
      )

      # Claimant fields (6)
      expect(ibm_payload).to include(
        'CLAIMANT_FIRST_NAME' => 'Jane',
        'CLAIMANT_MIDDLE_INITIAL' => 'B',
        'CLAIMANT_LAST_NAME' => 'Doe',
        'CLAIMANT_DOB' => '05/15/1992',
        'CLAIMANT_SSN' => '987654321'
      )
      expect(ibm_payload).to have_key('CL_FILE_NUMER')

      # Facility fields (7 address fields)
      expect(ibm_payload).to include(
        'NAME_FACILITY_C' => 'Sunrise Senior Living',
        'FACILITY_ADDRESS_LINE1_C' => '123 Care Lane',
        'FACILITY_ADDRESS_LINE2_C' => 'apt 1',
        'FACILITY_ADDRESS_CITY_C' => 'Springfield',
        'FACILITY_ADDRESS_STATE_C' => 'IL',
        'FACILITY_ADDRESS_COUNTRY_C' => 'USA',
        'FACILITY_ADDRESS_ZIP_C' => '62701'
      )

      # General information fields (17 from generalInformation section)
      expect(ibm_payload['DATE_ADMISSION_TO_FACILITY_C']).to eq('01/01/2024')
      expect(ibm_payload['MEDICAID_APPROVED_Y']).to be true
      expect(ibm_payload['MEDICAID_APPROVED_N']).to be false
      expect(ibm_payload['MEDICAID_APPLIED_Y']).to be true
      expect(ibm_payload['MEDICAID_APPLIED_N']).to be false
      expect(ibm_payload['MEDICAID_COVERAGE_Y']).to be true
      expect(ibm_payload['MEDICAID_COVERAGE_N']).to be false
      expect(ibm_payload['MEDICAID_START']).to eq('02/01/2024')
      expect(ibm_payload['OUT_OF_POCKET']).to eq('3000.00')
      expect(ibm_payload['SKILLED_CARE']).to be true
      expect(ibm_payload['INTERMEDIATE_CARE']).to be false
      expect(ibm_payload['NAME_COMPLETING_WORKSHEET_C']).to eq('Dr. Sarah Smith')
      expect(ibm_payload['ROLE_PERFORM_AT_FACILITY_C']).to eq('Director of Nursing')
      expect(ibm_payload['FACILITY_TELEPHONE_NUMBER_C']).to eq('5557890123')
      expect(ibm_payload['INT_PHONE_NUMBER']).to be_nil
      expect(ibm_payload['SIGNATURE_OF_PROVIDER_C']).to eq('Dr. Sarah Smith')
      expect(ibm_payload['SIGNATURE_DATE_PROVIDER_C']).to eq('01/01/2024')

      # Form metadata (4 fields including system fields)
      expect(ibm_payload).to include(
        'FLASH_TEXT' => nil,
        'CB_VA_STAMP' => nil,
        'FORM_TYPE' => '21-0779',
        'FORM_TYPE_1' => '21-0779'
      )
    end
  end
end
