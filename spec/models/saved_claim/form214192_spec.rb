# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Form214192, type: :model do
  let(:valid_form_data) { JSON.parse(Rails.root.join('spec', 'fixtures', 'form214192', 'valid_form.json').read) }
  let(:invalid_form_data) do
    JSON.parse(Rails.root.join('spec', 'fixtures', 'form214192', 'invalid_form.json').read)
  end

  let(:claim) { described_class.new(form: valid_form_data.to_json) }

  describe 'validations' do
    let(:claim) { described_class.new(form: form.to_json) }
    let(:form) { valid_form_data.dup }

    context 'with valid form data' do
      it 'validates successfully' do
        claim = described_class.new(form: valid_form_data.to_json)
        expect(claim).to be_valid
      end
    end

    context 'with invalid form data from fixture' do
      it 'fails validation for multiple reasons' do
        claim = described_class.new(form: invalid_form_data.to_json)
        expect(claim).not_to be_valid
        # Should fail because:
        # - middle name exceeds maxLength of 1
        # - missing SSN or VA file number
        # - missing required employment fields
      end
    end

    context 'OpenAPI schema validation' do
      it 'rejects middle name longer than 1 character' do
        form['veteranInformation']['fullName']['middle'] = 'AB'
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('string length')
        expect(claim.errors.full_messages.join).to include('is greater than: 1')
      end

      it 'rejects first name longer than 12 characters' do
        form['veteranInformation']['fullName']['first'] = 'A' * 31
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('string length')
        expect(claim.errors.full_messages.join).to include('is greater than: 30')
      end

      it 'rejects last name longer than 18 characters' do
        form['veteranInformation']['fullName']['last'] = 'A' * 31
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('string length')
        expect(claim.errors.full_messages.join).to include('is greater than: 30')
      end

      it 'rejects invalid SSN format' do
        form['veteranInformation']['ssn'] = '12345' # Too short
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('pattern')
      end

      it 'rejects address street exceeding maxLength' do
        form['veteranInformation']['address']['street'] = 'A' * 31 # Max is 30
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('string length')
        expect(claim.errors.full_messages.join).to include('is greater than: 30')
      end

      it 'accepts veteran address street2 up to 30 characters' do
        form['veteranInformation']['address']['street2'] = 'A' * 30
        expect(claim).to be_valid
      end

      it 'rejects veteran address street2 longer than 30 characters' do
        form['veteranInformation']['address']['street2'] = 'A' * 31
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('string length')
        expect(claim.errors.full_messages.join).to include('is greater than: 30')
      end

      it 'accepts employer address street2 up to 30 characters' do
        form['employmentInformation']['employerAddress']['street2'] = 'A' * 30
        expect(claim).to be_valid
      end

      it 'rejects employer address street2 longer than 30 characters' do
        form['employmentInformation']['employerAddress']['street2'] = 'A' * 31
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('string length')
        expect(claim.errors.full_messages.join).to include('is greater than: 30')
      end

      it 'requires country field in address' do
        form['veteranInformation']['address'].delete('country')
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('missing required properties')
      end

      it 'requires veteran information' do
        form.delete('veteranInformation')
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('missing required properties')
      end

      it 'requires employment information' do
        form.delete('employmentInformation')
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('missing required properties')
      end

      it 'requires veteran full name' do
        form['veteranInformation'].delete('fullName')
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('missing required properties')
      end

      it 'requires veteran date of birth' do
        form['veteranInformation'].delete('dateOfBirth')
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('missing required properties')
      end

      it 'requires employer name' do
        form['employmentInformation'].delete('employerName')
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('missing required properties')
      end

      it 'requires employer address' do
        form['employmentInformation'].delete('employerAddress')
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('missing required properties')
      end

      it 'requires type of work performed' do
        form['employmentInformation'].delete('typeOfWorkPerformed')
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('missing required properties')
      end

      it 'requires beginning date of employment' do
        form['employmentInformation'].delete('beginningDateOfEmployment')
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('missing required properties')
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
    it 'returns 119 for employment information' do
      expect(claim.document_type).to eq(119)
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

  describe '#attachment_keys' do
    it 'returns empty array (no attachments in MVP)' do
      expect(claim.attachment_keys).to eq([])
    end
  end

  describe '#to_pdf' do
    let(:pdf_path) { '/tmp/test_form.pdf' }
    let(:stamped_pdf_path) { '/tmp/test_form_stamped.pdf' }

    before do
      allow(PdfFill::Filler).to receive(:fill_form).and_return(pdf_path)
      allow(PdfFill::Forms::Va214192).to receive(:stamp_signature).and_return(stamped_pdf_path)
    end

    it 'generates PDF and stamps the signature' do
      result = claim.to_pdf

      expect(PdfFill::Filler).to have_received(:fill_form).with(claim, nil, {})
      expect(PdfFill::Forms::Va214192).to have_received(:stamp_signature).with(pdf_path, claim.parsed_form)
      expect(result).to eq(stamped_pdf_path)
    end

    it 'passes fill_options to the filler' do
      fill_options = { extras_redesign: true }
      claim.to_pdf('test-id', fill_options)

      expect(PdfFill::Filler).to have_received(:fill_form).with(claim, 'test-id', fill_options)
    end
  end

  describe '#metadata_for_benefits_intake' do
    context 'with all fields present' do
      it 'returns correct metadata hash' do
        metadata = claim.metadata_for_benefits_intake

        expect(metadata).to eq(
          veteranFirstName: 'John',
          veteranLastName: 'Doe',
          fileNumber: '987654321',
          zipCode: '54321',
          businessLine: 'CMP'
        )
      end
    end

    context 'when vaFileNumber is present' do
      it 'prefers vaFileNumber over ssn' do
        form_data = valid_form_data.dup
        form_data['veteranInformation']['vaFileNumber'] = '12345678'
        form_data['veteranInformation']['ssn'] = '999999999'
        claim_with_both = described_class.new(form: form_data.to_json)

        metadata = claim_with_both.metadata_for_benefits_intake

        expect(metadata[:fileNumber]).to eq('12345678')
      end
    end

    context 'when vaFileNumber is missing' do
      it 'falls back to ssn' do
        form_data = valid_form_data.dup
        form_data['veteranInformation'].delete('vaFileNumber')
        form_data['veteranInformation']['ssn'] = '111223333'
        claim_without_va_file = described_class.new(form: form_data.to_json)

        metadata = claim_without_va_file.metadata_for_benefits_intake

        expect(metadata[:fileNumber]).to eq('111223333')
      end
    end

    context 'when zipCode is missing' do
      it 'defaults to 00000 when employerAddress postalCode is missing' do
        form_data = valid_form_data.dup
        form_data['employmentInformation']['employerAddress'].delete('postalCode')
        claim_without_zip = described_class.new(form: form_data.to_json)

        metadata = claim_without_zip.metadata_for_benefits_intake

        expect(metadata[:zipCode]).to eq('00000')
      end

      it 'defaults to 00000 when employerAddress is missing' do
        form_data = valid_form_data.dup
        form_data['employmentInformation'].delete('employerAddress')
        claim_without_address = described_class.new(form: form_data.to_json)

        metadata = claim_without_address.metadata_for_benefits_intake

        expect(metadata[:zipCode]).to eq('00000')
      end
    end

    it 'always includes businessLine from business_line method' do
      metadata = claim.metadata_for_benefits_intake

      expect(metadata[:businessLine]).to eq('CMP')
      expect(metadata[:businessLine]).to eq(claim.business_line)
    end
  end

  describe '#to_ibm' do
    let(:claim) { described_class.new(form: valid_form_data.to_json) }
    let(:ibm_payload) { claim.to_ibm }

    it 'returns a hash with VBA Data Dictionary fields' do
      expect(ibm_payload).to be_a(Hash)
    end

    it 'includes veteran identification fields' do
      expect(ibm_payload).to include(
        'VETERAN_FIRST_NAME' => 'John',
        'VETERAN_INITIAL' => 'M',
        'VETERAN_LAST_NAME' => 'Doe',
        'VETERAN_SSN' => '123456789',
        'VA_FILE_NUMBER' => '987654321',
        'VETERAN_DOB' => '01/01/1980'
      )
    end

    it 'includes employer name and address combined field' do
      expect(ibm_payload['EMPLOYER_NAME_ADDRESS']).to include('Acme Corporation')
      expect(ibm_payload['EMPLOYER_NAME_ADDRESS']).to include('456 Business Ave')
      expect(ibm_payload['EMPLOYER_NAME_ADDRESS']).to include('Commerce City, CA')
      expect(ibm_payload['EMPLOYER_NAME_ADDRESS']).to include('54321')
    end

    it 'includes form metadata' do
      expect(ibm_payload).to include('FORM_TYPE' => '21-4192')
    end

    it 'handles missing middle name' do
      form_data = valid_form_data.dup
      form_data['veteranInformation']['fullName'].delete('middle')
      claim = described_class.new(form: form_data.to_json)
      payload = claim.to_ibm

      expect(payload['VETERAN_INITIAL']).to be_nil
    end

    it 'handles missing employer address street2' do
      form_data = valid_form_data.dup
      form_data['employmentInformation']['employerAddress'].delete('street2')
      claim = described_class.new(form: form_data.to_json)
      payload = claim.to_ibm

      expect(payload['EMPLOYER_NAME_ADDRESS']).to include('Acme Corporation')
      expect(payload['EMPLOYER_NAME_ADDRESS']).not_to include('200')
    end
  end

  describe 'FORM constant' do
    it 'is set to 21-4192' do
      expect(described_class::FORM).to eq('21-4192')
    end
  end
end
