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
                                    'last_4_ssn' => '6859',
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
                                      false,
                                      false,
                                      'MARCH',
                                      false,
                                      false,
                                      false,
                                      false,
                                      false,
                                      false,
                                      false,
                                      false,
                                      false
                                    ],
                                    'tax_year' => '2024'
                                  })
    end

    it 'sets coveredAll12Months correctly' do
      form_data['data']['coveredIndividual']['coveredAll12Months'] = false
      instance = described_class.parse(form_data)
      expect(instance.coverage_months[0]).to be(false)
      form_data['data']['coveredIndividual']['coveredAll12Months'] = true
      instance = described_class.parse(form_data)
      expect(instance.coverage_months[0]).to be(true)
    end

    it 'sets covered months as expected' do
      form_data['data']['coveredIndividual']['monthsCovered'] = %w[MARCH SEPTEMBER]
      instance = described_class.parse(form_data)
      expect(instance.coverage_months[1..12]).to eq(
        [false, false, 'MARCH', false, false, false, false, false, 'SEPTEMBER', false, false, false]
      )
    end

    it 'handles empty ssn' do
      form_data['data']['coveredIndividual']['ssn'] = ''
      instance = described_class.parse(form_data)
      expect(instance.last_4_ssn).to be_nil
    end

    it 'handles nil ssn' do
      form_data['data']['coveredIndividual']['ssn'] = nil
      instance = described_class.parse(form_data)
      expect(instance.last_4_ssn).to be_nil
    end
  end

  describe '.available_years' do
    before { Timecop.freeze(Time.zone.parse('2025-03-05T08:00:00Z')) }
    after { Timecop.return }

    context 'with start and end dates' do
      it 'returns all currently available years during which the user had coverage' do
        periods = [{ 'startDate' => '2015-03-05', 'endDate' => '2025-03-05' }]
        result = described_class.available_years(periods)
        expect(result).to eq([2024])
      end
    end

    context 'when end date is nil' do
      it 'infers that the user is still covered and returns all currently available years' do
        periods = [{ 'startDate' => '2015-03-05', 'endDate' => nil }]
        result = described_class.available_years(periods)
        expect(result).to eq([2024])
      end
    end

    context 'with multiple periods' do
      it 'returns all currently available years during which the user had coverage' do
        periods = [{ 'startDate' => '2015-03-05', 'endDate' => '2017-03-05' },
                   { 'startDate' => '2020-03-05', 'endDate' => '2021-03-05' },
                   { 'startDate' => '2022-03-05', 'endDate' => '2022-04-05' },
                   { 'startDate' => '2024-03-05', 'endDate' => nil }]
        result = described_class.available_years(periods)
        expect(result).to eq([2024])
      end
    end

    context 'when user was not covered during available years' do
      it 'returns an empty array' do
        periods = [{ 'startDate' => '2015-03-05', 'endDate' => '2020-03-05' }]
        result = described_class.available_years(periods)
        expect(result).to eq([])
      end
    end
  end

  describe '.available_years_range' do
    before { Timecop.freeze(Time.zone.parse('2025-03-05T08:00:00Z')) }
    after { Timecop.return }

    it 'returns an array containing first and last years of accessible 1095-B data' do
      result = described_class.available_years_range
      expect(result).to eq([2024, 2024])
    end
  end

  describe '.pdf_template_path' do
    it 'returns the path to the pdf template' do
      expect(described_class.pdf_template_path(2023)).to eq(
        'lib/veteran_enrollment_system/form1095_b/templates/pdfs/1095b-2023.pdf'
      )
    end
  end

  describe '.txt_template_path' do
    it 'returns the path to the txt template' do
      expect(described_class.txt_template_path(2023)).to eq(
        'lib/veteran_enrollment_system/form1095_b/templates/txts/1095b-2023.txt'
      )
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

    context 'when user has a middle name' do
      it 'presents name correctly' do
        expect(form1095b.txt_file).to include(
          '1 Name of responsible individual-First name, middle name, last name ---- John Michael Smith'
        )
        expect(form1095b.txt_file).to include(
          '(a) Name of covered individual(s) First name, middle initial, last name ---- John M Smith'
        )
      end
    end

    context 'when user has no middle name' do
      let(:form1095b) { build(:enrollment_system_form1095_b, middle_name: nil) }

      it 'presents name correctly' do
        expect(form1095b.txt_file).to include(
          '1 Name of responsible individual-First name, middle name, last name ---- John Smith'
        )
        expect(form1095b.txt_file).to include(
          '(a) Name of covered individual(s) First name, middle initial, last name ---- John Smith'
        )
      end
    end

    context 'when user has an empty middle name' do
      let(:form1095b) { build(:enrollment_system_form1095_b, middle_name: '') }

      it 'presents name correctly' do
        expect(form1095b.txt_file).to include(
          '1 Name of responsible individual-First name, middle name, last name ---- John Smith'
        )
        expect(form1095b.txt_file).to include(
          '(a) Name of covered individual(s) First name, middle initial, last name ---- John Smith'
        )
      end
    end
  end
end
