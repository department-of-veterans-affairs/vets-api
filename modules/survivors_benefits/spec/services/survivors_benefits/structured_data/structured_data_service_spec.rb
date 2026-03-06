# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/structured_data_service'

RSpec.describe SurvivorsBenefits::StructuredData::StructuredDataService do
  # it includes the expected modules
  it 'includes the expected modules' do
    expect(SurvivorsBenefits::StructuredData::StructuredDataService.ancestors).to include(
      HasStructuredData,
      SurvivorsBenefits::StructuredData::Section01,
      SurvivorsBenefits::StructuredData::Section02,
      SurvivorsBenefits::StructuredData::Section03,
      SurvivorsBenefits::StructuredData::Section04,
      SurvivorsBenefits::StructuredData::Section05,
      SurvivorsBenefits::StructuredData::Section06,
      SurvivorsBenefits::StructuredData::Section07,
      SurvivorsBenefits::StructuredData::Section08,
      SurvivorsBenefits::StructuredData::Section09,
      SurvivorsBenefits::StructuredData::Section10,
      SurvivorsBenefits::StructuredData::Section11,
      SurvivorsBenefits::StructuredData::Section12
    )
  end

  describe '#initialize' do
    it 'initializes with form and fields' do
      form = { 'key' => 'value' }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service.form).to eq(form)
      expect(service.fields).to be_a(Hash)
    end
  end

  describe '#build_structured_data' do
    it 'calls the expected merge methods in build_structured_data' do
      form = {}
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:build_section1)
      expect(service).to receive(:build_section2)
      expect(service).to receive(:build_section3)
      expect(service).to receive(:build_section4)
      expect(service).to receive(:build_section5)
      expect(service).to receive(:build_section6)
      expect(service).to receive(:build_section7)
      expect(service).to receive(:build_section8)
      expect(service).to receive(:build_section9)
      expect(service).to receive(:build_section10)
      expect(service).to receive(:build_section11).with(form['bankAccount'])
      expect(service).to receive(:build_section12)
      service.build_structured_data
    end
  end

  describe '#merge_name_fields' do
    describe 'When all name fields are present' do
      it 'merges name fields into the correct structured data' do
        form = {}
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        name = {
          'first' => 'John',
          'middle' => 'A',
          'last' => 'Doe',
          'suffix' => 'Jr.'
        }
        individual = 'VETERAN'
        service.merge_name_fields(name, individual)
        expect(service.fields['VETERAN_NAME']).to eq('John A Doe Jr.')
        expect(service.fields['VETERAN_FIRST_NAME']).to eq('John')
        expect(service.fields['VETERAN_MIDDLE_INITIAL']).to eq('A')
        expect(service.fields['VETERAN_LAST_NAME']).to eq('Doe')
      end
    end

    describe 'When some name fields are missing' do
      it 'merges available name fields and leaves missing fields nil' do
        form = {}
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        name = {
          'first' => 'Jane',
          'last' => 'Smith'
        }
        individual = 'CLAIMANT'
        service.merge_name_fields(name, individual)
        expect(service.fields['CLAIMANT_NAME']).to eq('Jane Smith')
        expect(service.fields['CLAIMANT_FIRST_NAME']).to eq('Jane')
        expect(service.fields['CLAIMANT_MIDDLE_INITIAL']).to be_nil
        expect(service.fields['CLAIMANT_LAST_NAME']).to eq('Smith')
      end
    end

    describe 'When name is nil' do
      it 'does not merge any fields' do
        form = {}
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        individual = 'VETERAN'
        service.merge_name_fields(nil, individual)
        expect(service.fields['VETERAN_NAME']).to be_nil
        expect(service.fields['VETERAN_FIRST_NAME']).to be_nil
        expect(service.fields['VETERAN_MIDDLE_INITIAL']).to be_nil
        expect(service.fields['VETERAN_LAST_NAME']).to be_nil
      end
    end
  end
end
