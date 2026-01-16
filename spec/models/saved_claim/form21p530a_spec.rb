# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Form21p530a, type: :model do
  let(:valid_form_data) { JSON.parse(Rails.root.join('spec', 'fixtures', 'form21p530a', 'valid_form.json').read) }
  let(:invalid_form_data) do
    JSON.parse(Rails.root.join('spec', 'fixtures', 'form21p530a', 'invalid_form.json').read)
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
        # - aptOrUnitNumber exceeds maxLength of 5
        # - missing certification signature
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

      it 'accepts aptOrUnitNumber up to 5 characters' do
        form['burialInformation']['recipientOrganization']['address']['aptOrUnitNumber'] = 'A' * 5
        expect(claim).to be_valid
      end

      it 'rejects aptOrUnitNumber longer than 5 characters' do
        form['burialInformation']['recipientOrganization']['address']['aptOrUnitNumber'] = 'A' * 6
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('string length')
        expect(claim.errors.full_messages.join).to include('is greater than: 5')
      end

      it 'accepts country codes up to 3 characters' do
        form['burialInformation']['recipientOrganization']['address']['country'] = 'USA'
        expect(claim).to be_valid
      end

      it 'rejects country longer than 3 characters' do
        form['burialInformation']['recipientOrganization']['address']['country'] = 'USAA'
        expect(claim).not_to be_valid
        expect(claim.errors.full_messages.join).to include('string length')
        expect(claim.errors.full_messages.join).to include('is greater than: 3')
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

      it 'requires veteran date of death' do
        form['veteranInformation'].delete('dateOfDeath')
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
    it 'returns PMC for pension management center' do
      expect(claim.business_line).to eq('PMC')
    end
  end

  describe '#document_type' do
    it 'returns 540 for burial/memorial benefits' do
      expect(claim.document_type).to eq(540)
    end
  end

  describe '#regional_office' do
    it 'returns Pension Management Center address' do
      expected_address = [
        'Department of Veterans Affairs',
        'Pension Management Center',
        'P.O. Box 5365',
        'Janesville, WI 53547-5365'
      ]
      expect(claim.regional_office).to eq(expected_address)
    end
  end

  describe '#process_attachments!' do
    it 'queues Lighthouse submission job without attachments' do
      allow(claim).to receive(:id).and_return(123)
      expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async).with(123)
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
    let(:parsed_form_data) do
      {
        'certification' => {
          'signature' => 'John Doe'
        }
      }
    end

    before do
      allow(PdfFill::Filler).to receive(:fill_form).and_return(pdf_path)
      allow(PdfFill::Forms::Va21p530a).to receive(:stamp_signature).and_return(stamped_pdf_path)
      allow(claim).to receive(:parsed_form).and_return(parsed_form_data)
    end

    it 'generates PDF and stamps the signature' do
      result = claim.to_pdf

      expect(PdfFill::Filler).to have_received(:fill_form).with(claim, nil, {})
      expect(PdfFill::Forms::Va21p530a).to have_received(:stamp_signature).with(pdf_path, parsed_form_data)
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
  end

  describe 'FORM constant' do
    it 'is set to 21P-530a' do
      expect(described_class::FORM).to eq('21P-530a')
    end
  end

  describe '#metadata_for_benefits_intake' do
    context 'with all fields present' do
      it 'returns correct metadata hash' do
        metadata = claim.metadata_for_benefits_intake

        expect(metadata).to eq(
          veteranFirstName: 'John',
          veteranLastName: 'Doe',
          fileNumber: '123456789',
          zipCode: '64037',
          businessLine: 'PMC'
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
      it 'defaults to 00000 when recipientOrganization address postalCode is missing' do
        form_data = valid_form_data.dup
        form_data['burialInformation']['recipientOrganization']['address'].delete('postalCode')
        claim_without_zip = described_class.new(form: form_data.to_json)

        metadata = claim_without_zip.metadata_for_benefits_intake

        expect(metadata[:zipCode]).to eq('00000')
      end

      it 'defaults to 00000 when recipientOrganization address is missing' do
        form_data = valid_form_data.dup
        form_data['burialInformation']['recipientOrganization'].delete('address')
        claim_without_address = described_class.new(form: form_data.to_json)

        metadata = claim_without_address.metadata_for_benefits_intake

        expect(metadata[:zipCode]).to eq('00000')
      end

      it 'defaults to 00000 when recipientOrganization is missing' do
        form_data = valid_form_data.dup
        form_data['burialInformation'].delete('recipientOrganization')
        claim_without_org = described_class.new(form: form_data.to_json)

        metadata = claim_without_org.metadata_for_benefits_intake

        expect(metadata[:zipCode]).to eq('00000')
      end
    end

    it 'always includes businessLine from business_line method' do
      metadata = claim.metadata_for_benefits_intake

      expect(metadata[:businessLine]).to eq('PMC')
      expect(metadata[:businessLine]).to eq(claim.business_line)
    end
  end

  describe 'private methods' do
    describe '#organization_name' do
      it 'returns recipient organization name when present' do
        expect(claim.send(:organization_name)).to eq('Missouri Veterans Commission')
      end

      it 'returns nameOfStateCemeteryOrTribalOrganization when recipient name is missing' do
        form_data = valid_form_data.dup
        form_data['burialInformation'].delete('recipientOrganization')
        claim_without_recipient = described_class.new(form: form_data.to_json)
        expect(claim_without_recipient.send(:organization_name)).to eq('Missouri State Veterans Cemetery')
      end
    end

    describe '#veteran_name' do
      it 'returns full name when present' do
        expect(claim.send(:veteran_name)).to eq('John Doe')
      end
    end
  end
end
