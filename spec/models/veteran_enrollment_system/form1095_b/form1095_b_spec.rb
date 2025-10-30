# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranEnrollmentSystem::Form1095B::Form1095B, type: :model do
  let(:form_data) do
    { 'data' =>
      { 'issuer' =>
        { 'issuerName' => 'US Department of Veterans Affairs',
          'ein' => '54-2002017',
          'contactPhoneNumber' => '877-222-8387',
          'address' => { 'street1' => 'PO Box 149975', 'city' => 'Austin', 'stateOrProvince' => 'TX',
                         'zipOrPostalCode' => '78714-8975', 'country' => 'USA' } },
        'responsibleIndividual' =>
        { 'name' => { 'firstName' => 'HECTOR', 'lastName' => 'ALLEN' },
          'address' => { 'street1' => 'PO BOX 494', 'city' => 'MOCA', 'stateOrProvince' => 'PR',
                         'zipOrPostalCode' => '00676-0494', 'country' => 'USA' },
          'ssn' => '796126859',
          'dateOfBirth' => '19320205' },
        'coveredIndividual' =>
        { 'name' => { 'firstName' => 'HECTOR', 'lastName' => 'ALLEN' }, 'ssn' => '796126859',
          'dateOfBirth' => '19320205', 'coveredAll12Months' => false, 'monthsCovered' => ['MARCH'] },
        'taxYear' => '2024' },
      'messages' => [] }
  end

  describe '.parse' do
    it 'returns an instance of model with expected attributes' do
      rv = described_class.parse(form_data)
      expect(rv).to be_instance_of(described_class)
      expect(rv.attributes).to eq({
                                    'first_name' => 'HECTOR',
                                    'middle_name' => nil,
                                    'last_name' => 'ALLEN',
                                    'last_4_ssn' => '796126859',
                                    'birth_date' => '1932-02-05'.to_date,
                                    'address' => 'PO BOX 494',
                                    'city' => 'MOCA',
                                    'state' => 'PR',
                                    'province' => 'PR',
                                    'country' => 'USA',
                                    'zip_code' => '00676-0494',
                                    'foreign_zip' => '00676-0494',
                                    'is_beneficiary' => false,
                                    'is_corrected' => false,
                                    'coverage_months' => [
                                      false,
                                      nil,
                                      nil,
                                      'MARCH',
                                      nil,
                                      nil,
                                      nil,
                                      nil,
                                      nil,
                                      nil,
                                      nil,
                                      nil,
                                      nil
                                    ],
                                    'tax_year' => '2024'
                                  })
    end
  end

  describe '.coverage_months' do
    it 'sets coveredAll12Months correctly at start of return array' do
      data = { 'data' => { 'coveredIndividual' => { 'coveredAll12Months' => false, 'monthsCovered' => [] } } }
      rv = described_class.coverage_months(data)
      expect(rv[0]).to be(false)
      data['data']['coveredIndividual']['coveredAll12Months'] = true
      rv = described_class.coverage_months(data)
      expect(rv[0]).to be(true)
    end

    it 'sets covered months as expected' do
      data = { 'data' => { 'coveredIndividual' => { 'monthsCovered' => %w[MARCH SEPTEMBER] } } }
      rv = described_class.coverage_months(data)
      expect(rv[1..12]).to eq([nil, nil, 'MARCH', nil, nil, nil, nil, nil, 'SEPTEMBER', nil, nil, nil])
    end
  end

  describe 'pdf_testing' do
    describe 'valid pdf generation' do
      it 'generates pdf string for valid 1095_b' do
        expect(subject.pdf_file.class).to eq(String)
      end
    end

    describe 'invalid PDF generation' do
      let(:inv_year_form) { create(:form1095_b, veteran_icn: '654678976543678', tax_year: 2008) }

      it 'fails if no template PDF for the tax_year' do
        expect { inv_year_form.pdf_file }.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end

  describe 'txt_testing' do
    describe 'valid text file generation' do
      it 'generates text string for valid 1095_b' do
        expect(subject.txt_file.class).to eq(String)
      end
    end

    describe 'invalid txt generation' do
      let(:inv_year_form) { create(:form1095_b, veteran_icn: '654678976543678', tax_year: 2008) }

      it 'fails if no template txt file for the tax_year' do
        expect { inv_year_form.txt_file }.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
