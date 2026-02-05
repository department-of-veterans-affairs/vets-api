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

  describe '#to_ibm' do
    let(:claim) { create(:va210779) }
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
      expect(ibm_payload).to include(
        'CLAIMANT_FIRST_NAME' => claimant.dig('fullName', 'first'),
        'CLAIMANT_LAST_NAME' => claimant.dig('fullName', 'last')
      )
    end

    it 'includes form metadata' do
      expect(ibm_payload).to include('FORM_TYPE' => '21-0779')
    end

    it 'formats dates in MM/DD/YYYY format' do
      parsed = JSON.parse(claim.form)
      if parsed.dig('veteranInformation', 'dateOfBirth')
        dob = ibm_payload['VETERAN_DOB']
        expect(dob).to match(%r{\d{2}/\d{2}/\d{4}}) if dob.present?
      end
    end

    it 'handles checkbox values as X or nil' do
      # Medicaid checkboxes should be 'X' for true, nil for false
      medicaid_approved = ibm_payload['MEDICAID_APPROVED']
      expect([nil, 'X']).to include(medicaid_approved)
    end
  end
end
