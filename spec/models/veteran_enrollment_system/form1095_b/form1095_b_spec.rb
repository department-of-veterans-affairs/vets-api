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
  let(:form1095b) { build(:enrollment_system_form1095_b) }

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
      result = described_class.coverage_months(data)
      expect(result[0]).to be(false)
      data['data']['coveredIndividual']['coveredAll12Months'] = true
      result = described_class.coverage_months(data)
      expect(result[0]).to be(true)
    end

    it 'sets covered months as expected' do
      data = { 'data' => { 'coveredIndividual' => { 'monthsCovered' => %w[MARCH SEPTEMBER] } } }
      result = described_class.coverage_months(data)
      expect(result[1..12]).to eq([nil, nil, 'MARCH', nil, nil, nil, nil, nil, 'SEPTEMBER', nil, nil, nil])
    end
  end

  describe '.available_years' do
    before { Timecop.freeze(Time.zone.parse('2025-03-05T08:00:00Z')) }
    after { Timecop.return }

    context 'with start and end dates' do
      it 'returns available years' do
        periods = [{ 'startDate' => '2015-03-05', 'endDate' => '2025-03-05' }]
        result = described_class.available_years(periods)
        expect(result).to eq([2021, 2022, 2023, 2024])
      end
    end

    context 'when end date is nil' do
      it 'returns available years' do
        periods = [{ 'startDate' => '2015-03-05', 'endDate' => nil }]
        result = described_class.available_years(periods)
        expect(result).to eq([2021, 2022, 2023, 2024])
      end
    end

    context 'with multiple periods' do
      it 'returns available years' do
        periods = [{ 'startDate' => '2015-03-05', 'endDate' => '2022-03-05' },
                   { 'startDate' => '2024-03-05', 'endDate' => nil }]
        result = described_class.available_years(periods)
        expect(result).to eq([2021, 2022, 2024])
      end
    end
  end

  describe '#pdf_file' do
    context 'when template is present' do
      it 'generates pdf string for valid 1095_b' do
        expect(form1095b.pdf_file.class).to eq(String)
      end
    end

    context 'when template is not present' do
      let(:inv_year_form) { build(:enrollment_system_form1095_b, tax_year: 2008) }

      it 'raises error' do
        expect { inv_year_form.pdf_file }.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end

    context 'when error occurs creating pdf file' do
      it 'raises error' do
        allow_any_instance_of(PdfForms::PdftkWrapper).to receive(:fill_form).and_raise(PdfForms::PdftkError)
        expect { form1095b.pdf_file }.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end

  describe '#txt_file' do
    context 'when template is present' do
      it 'generates text string for valid 1095_b' do
        expect(form1095b.txt_file.class).to eq(String)
      end
    end

    context 'when template is not present' do
      let(:inv_year_form) { build(:enrollment_system_form1095_b, tax_year: 2008) }

      it 'raises error' do
        expect { inv_year_form.txt_file }.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
