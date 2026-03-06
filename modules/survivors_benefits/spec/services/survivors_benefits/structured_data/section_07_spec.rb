# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_07'

RSpec.describe SurvivorsBenefits::StructuredData::Section07 do
  describe '#build_section7' do
    it 'calls merge_dic_type_fields' do
      form = { 'benefit' => 'DIC' }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_dic_type_fields).with(form['benefit'])
      service.build_section7
    end

    it 'merges expected fields for all treatments' do
      form = {
        'treatments' => [
          { 'facility' => 'VA Center 1, Anytown, WA', 'startDate' => '2020-01-01', 'endDate' => '2020-01-10' },
          { 'facility' => 'VA Center 2, Othertown, WA', 'startDate' => '2021-02-01', 'endDate' => '2021-02-15' }
        ]
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section7
      expect(service.fields).to include(
        'NAME_LOC_MED_CENTER_1' => 'VA Center 1, Anytown, WA',
        'DATE_OF_TREATMENT_START1' => '01/01/2020',
        'DATE_OF_TREATMENT_END1' => '01/10/2020',
        'NAME_LOC_MED_CENTER_2' => 'VA Center 2, Othertown, WA',
        'DATE_OF_TREATMENT_START2' => '02/01/2021',
        'DATE_OF_TREATMENT_END2' => '02/15/2021'
      )
    end
  end

  describe '#merge_dic_type_fields' do
    it 'sets correct fields for DIC benefit' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.merge_dic_type_fields('DIC')
      expect(service.fields).to include(
        'BENEFIT_DIC' => true,
        'BENEFIT_DIC38' => false,
        'CLAIM_TYPE_DIC_PACTACT' => false
      )
    end

    it 'sets correct fields for 1151DIC benefit' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.merge_dic_type_fields('1151DIC')
      expect(service.fields).to include(
        'BENEFIT_DIC' => false,
        'BENEFIT_DIC38' => true,
        'CLAIM_TYPE_DIC_PACTACT' => false
      )
    end

    it 'sets correct fields for pactActDIC benefit' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.merge_dic_type_fields('pactActDIC')
      expect(service.fields).to include(
        'BENEFIT_DIC' => false,
        'BENEFIT_DIC38' => false,
        'CLAIM_TYPE_DIC_PACTACT' => true
      )
    end
  end
end
