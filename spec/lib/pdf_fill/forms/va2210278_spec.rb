# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va2210278'

describe PdfFill::Forms::Va2210278 do
  let(:form_data) do
    JSON.parse(Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '10278', 'minimal.json').read)
  end

  let(:form_class) { described_class.new(form_data) }

  describe '#merge_fields' do
    subject(:merged_fields) { form_class.merge_fields }

    context 'Claimant Personal Information' do
      it 'combines full name' do
        expect(merged_fields.dig('claimantPersonalInformation', 'fullName')).to eq('John Quincy Doe')
      end

      it 'splits and formats SSN correctly into all 3 fields' do
        expect(merged_fields.dig('claimantPersonalInformation', 'ssn')).to eq('123456789')
        expect(merged_fields['ssn2']).to eq('123456789')
        expect(merged_fields['ssn3']).to eq('123456789')
      end

      it 'formats date of birth' do
        expect(merged_fields.dig('claimantPersonalInformation', 'dateOfBirth')).to eq('01/01/1980')
      end

      it 'handles missing date of birth' do
        form_data['claimantPersonalInformation'].delete('dateOfBirth')
        expect(merged_fields.dig('claimantPersonalInformation', 'dateOfBirth')).to be_nil
      end

      it 'handles invalid date format gracefully' do
        form_data['claimantPersonalInformation']['dateOfBirth'] = 'not-a-date'
        expect(merged_fields.dig('claimantPersonalInformation', 'dateOfBirth')).to eq('not-a-date')
      end
    end

    context 'Claimant Address' do
      it 'formats standard address structure' do
        expected_address = "123 Main St\nAnytown, NY, 12345\nUSA"
        expect(merged_fields['claimantAddress']).to eq(expected_address)
      end

      it 'formats profileAddress structure' do
        form_data['claimantAddress'] = {
          'addressLine1' => '123 Profile St',
          'addressLine2' => 'Apt 4',
          'city' => 'Profile City',
          'stateCode' => 'PC',
          'zipCode' => '54321',
          'countryName' => 'Profile Country'
        }

        expected_address = "123 Profile St\nApt 4\nProfile City, PC, 54321\nProfile Country"
        expect(merged_fields['claimantAddress']).to eq(expected_address)
      end
    end

    context 'Third Party Information' do
      it 'formats person name' do
        expect(merged_fields['thirdPartyPersonName']).to eq('Jane Smith')
      end

      it 'formats person address' do
        expected_address = "456 Elm St\nOthertown, CA, 90210\nUSA"
        expect(merged_fields['thirdPartyPersonAddress']).to eq(expected_address)
      end

      it 'handles missing person name' do
        form_data.delete('thirdPartyPersonName')
        expect(merged_fields['thirdPartyPersonName']).to be_nil
      end
    end

    context 'Organization Information' do
      it 'formats organization address' do
        expected_address = "789 Oak Ave\nBig City, TX, 75001\nUSA"
        expect(merged_fields.dig('thirdPartyOrganizationInformation', 'organizationAddress')).to eq(expected_address)
      end

      it 'maps organization representatives to simple string list' do
        reps = merged_fields['organizationRepresentatives']
        expect(reps).to be_an(Array)
        expect(reps[0]).to eq('Rep One')
        expect(reps[1]).to eq('Rep Two')
      end

      it 'handles missing organization representatives' do
        form_data.delete('organizationRepresentatives')
        expect(merged_fields['organizationRepresentatives']).to be_nil
      end
    end

    context 'Claim Information' do
      it 'sets X for selected items and determines isLimited' do
        expect(merged_fields.dig('claimInformation', 'statusOfClaim')).to eq('X')
        expect(merged_fields.dig('claimInformation', 'paymentHistory')).to eq('X')
        expect(merged_fields.dig('claimInformation', 'currentBenefit')).to be_nil

        expect(merged_fields['isLimited']).to eq('X')
        expect(merged_fields['isNotLimited']).to be_nil
      end

      it 'sets isNotLimited when no items are selected' do
        form_data['claimInformation'] = {
          'statusOfClaim' => false,
          'paymentHistory' => false
        }

        expect(merged_fields.dig('claimInformation', 'statusOfClaim')).to be_nil
        expect(merged_fields['isLimited']).to be_nil
        expect(merged_fields['isNotLimited']).to eq('X')
      end

      it 'handles missing claim information' do
        form_data.delete('claimInformation')
        expect(merged_fields['claimInformation']).to be_nil
      end
    end

    context 'Length of Release' do
      it 'handles date release' do
        expect(merged_fields.dig('lengthOfRelease', 'isDated')).to eq('X')
        expect(merged_fields.dig('lengthOfRelease', 'isOngoing')).to be_nil
        expect(merged_fields.dig('lengthOfRelease', 'releaseDate')).to eq('12/31/2025')
      end

      it 'handles ongoing release' do
        form_data['lengthOfRelease'] = { 'lengthOfRelease' => 'ongoing' }

        expect(merged_fields.dig('lengthOfRelease', 'isDated')).to be_nil
        expect(merged_fields.dig('lengthOfRelease', 'isOngoing')).to eq('X')
        expect(merged_fields.dig('lengthOfRelease', 'releaseDate')).to be_nil
      end

      it 'handles missing length of release' do
        form_data.delete('lengthOfRelease')
        expect(merged_fields['lengthOfRelease']).to be_nil
      end
    end

    context 'Security Info' do
      it 'maps standard question' do
        expect(merged_fields.dig('securityQuestion', 'question'))
          .to eq('The city and state your mother was born in')
      end

      it 'maps location answer' do
        expect(merged_fields.dig('securityAnswer', 'answer')).to eq('Smallville, KS')
      end

      it 'maps create question and answer' do
        form_data['securityQuestion'] = { 'question' => 'create' }
        form_data['securityAnswer'] = {
          'securityAnswerCreate' => {
            'question' => 'Custom Q',
            'answer' => 'Custom A'
          }
        }

        expect(merged_fields.dig('securityQuestion', 'question')).to eq('Custom Q')
        expect(merged_fields.dig('securityAnswer', 'answer')).to eq('Custom A')
      end

      it 'maps text answer' do
        form_data['securityQuestion'] = { 'question' => 'pin' }
        form_data['securityAnswer'] = { 'securityAnswerText' => '1234' }

        expect(merged_fields.dig('securityQuestion', 'question')).to eq('I would like to use a pin or password')
        expect(merged_fields.dig('securityAnswer', 'answer')).to eq('1234')
      end

      it 'handles missing security question' do
        form_data.delete('securityQuestion')
        expect(merged_fields['securityQuestion']).to be_nil
      end

      it 'handles missing security answer' do
        form_data.delete('securityAnswer')
        expect(merged_fields['securityAnswer']).to be_nil
      end
    end

    context 'General' do
      it 'formats date signed' do
        expect(merged_fields['dateSigned']).to eq('10/27/2023')
      end

      it 'handles missing date signed' do
        form_data.delete('dateSigned')
        expect(merged_fields['dateSigned']).to be_nil
      end
    end
  end

  describe 'filling out pdf' do
    # let(:file_path) { 'tmp/pdfs/10278_test' }
    let(:claim) { create(:va10278) }

    after do
      FileUtils.rm_rf('tmp/pdfs')
    end

    def get_field_value(fields, name)
      fields.find { |f| f.name == name }&.value
    end

    it 'fills in the correct field values' do
      file_path = claim.to_pdf
      fields = PdfForms.new(Settings.binaries.pdftk).get_fields(file_path)

      expect(get_field_value(fields, 'fullName')).to eq 'John Quincy Doe'
      expect(get_field_value(fields, 'ssn')).to eq '123456789'
      expect(get_field_value(fields, 'dateOfBirth')).to eq '01/01/1980'
      expect(get_field_value(fields, 'emailAddress')).to eq 'john.doe@example.com'
      expect(get_field_value(fields, 'question')).to eq 'The city and state your mother was born in'
      expect(get_field_value(fields, 'answer')).to eq 'Smallville, KS'
      expect(get_field_value(fields, 'statementOfTruthSignature')).to eq 'John Q Doe'
    end
  end
end
