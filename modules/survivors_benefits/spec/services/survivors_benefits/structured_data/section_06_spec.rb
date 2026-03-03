# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_06'

RSpec.describe SurvivorsBenefits::StructuredData::Section06 do
  describe '#build_section6' do
    describe 'when claimant lives with children' do
      it 'does not call merge_custodian_fields' do
        form = { 'childrenLiveTogetherButNotWithSpouse' => true }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        expect(service).not_to receive(:merge_custodian_fields)
        service.build_section6
      end
    end

    describe 'when claimant does not live with children' do
      it 'calls merge_custodian_fields' do
        form = { 'childrenLiveTogetherButNotWithSpouse' => false }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        expect(service).to receive(:merge_custodian_fields)
        service.build_section6
      end
    end

    it 'calls merge_child_relationship_fields for each child' do
      form = {
        'childrenLiveTogetherButNotWithSpouse' => true,
        'veteransChildren' => [
          { 'relationship' => 'BIOLOGICAL' },
          { 'relationship' => 'ADOPTED' },
          { 'relationship' => 'STEPCHILD' }
        ]
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_child_relationship_fields).with('BIOLOGICAL', 1)
      expect(service).to receive(:merge_child_relationship_fields).with('ADOPTED', 2)
      expect(service).to receive(:merge_child_relationship_fields).with('STEPCHILD', 3)
      service.build_section6
    end

    it 'calls build_and_merge_child for each child' do
      form = {
        'childrenLiveTogetherButNotWithSpouse' => true,
        'veteransChildren' => [
          { 'relationship' => 'BIOLOGICAL', 'childFullName' => { 'first' => 'John', 'last' => 'Doe' } },
          { 'relationship' => 'ADOPTED', 'childFullName' => { 'first' => 'Jane', 'last' => 'Smith' } }
        ]
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:build_and_merge_child).with(form['veteransChildren'][0], 1)
      expect(service).to receive(:build_and_merge_child).with(form['veteransChildren'][1], 2)
      service.build_section6
    end

    it 'handles nil children array' do
      form = { 'childrenLiveTogetherButNotWithSpouse' => true, 'veteransChildren' => nil }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect { service.build_section6 }.not_to raise_error
    end

    it 'merges other expected fields' do
      form = {
        'childrenLiveTogetherButNotWithSpouse' => true,
        'veteranChildrenCount' => 3

      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section6
      expect(service.fields).to include(
        'CHILD_DO_NOT_LIVE_WITH_CL_Y' => false,
        'CHILD_DO_NOT_LIVE_WITH_CL_N' => true,
        'NUMBER_OF_DEP_CHILD' => 3
      )
    end
  end

  describe '#merge_custodian_fields' do
    it 'merges custodian name and address fields' do
      form = {
        'custodianFullName' => { 'first' => 'Alice', 'middle' => 'B', 'last' => 'Johnson' },
        'custodianAddress' => {
          'street' => '789 B St',
          'street2' => 'Apt 4',
          'city' => 'Othertown',
          'state' => 'NY',
          'country' => 'US',
          'postalCode' => '54321-1234'
        }
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.merge_custodian_fields
      expect(service.fields).to include(
        'CUSTODIAN_CHILD1_NAME' => 'Alice B Johnson',
        'CUSTODIAN_CHILD1_FIRST_NAME' => 'Alice',
        'CUSTODIAN_CHILD1_MID_INT' => 'B',
        'CUSTODIAN_CHILD1_LAST_NAME' => 'Johnson',
        'CUSTODIAN_ADDRESS_LINE_1' => '789 B St',
        'CUSTODIAN_ADDRESS_LINE_2' => 'Apt 4',
        'CUSTODIAN_ADDRESS_CITY' => 'Othertown',
        'CUSTODIAN_ADDRESS_STATE' => 'NY',
        'CUSTODIAN_ADDRESS_COUNTRY' => 'US',
        'CUSTODIAN_ADDRESS_ZIP' => '54321',
        'CUSTODIAN_CHILD_NAME_ADDRESS' =>
          'Alice B Johnson, 789 B St Apt 4 Othertown NY 54321-1234 US'
      )
    end
  end

  describe '#merge_child_relationship_fields' do
    it 'merges child relationship fields correctly' do
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.merge_child_relationship_fields('BIOLOGICAL', 1)
      service.merge_child_relationship_fields('ADOPTED', 2)
      service.merge_child_relationship_fields('STEPCHILD', 3)
      expect(service.fields).to include(
        'BIOLOGICAL_CHILD_1' => true,
        'ADOPTED_CHILD_1' => false,
        'STEPCHILD_1' => false,
        'BIOLOGICAL_CHILD_2' => false,
        'ADOPTED_CHILD_2' => true,
        'STEPCHILD_2' => false,
        'BIOLOGICAL_CHILD_3' => false,
        'ADOPTED_CHILD_3' => false,
        'STEPCHILD_3' => true
      )
    end
  end

  # NAME_OF_CHILD_#{child_num}
  # FIRST_NAME_OF_CHILD_#{child_num}
  # MID_INT_OF_CHILD_#{child_num}
  # LAST_NAME_OF_CHILD_#{child_num}
  # DATE_OF_BIRTH_CHILD_#{child_num}
  # CHILD_#{child_num}_SSN
  # PLACE_OF_BIRTH_CHILD_#{child_num}
  # CHILD_#{child_num}_18_TO_23
  # CHILD_#{child_num}_DISABLED
  # CHILD_#{child_num}_PREV_MARRIED
  # CB_CHILD#{child_num}_LIVE_WITH_OTHERS
  # AMNT_CONTRIBUTE_TO_CHILD_#{child_num}
  describe '#build_and_merge_child' do
    it 'builds and merges child fields correctly' do
      child = {
        'childFullName' => { 'first' => 'Emily', 'middle' => 'C', 'last' => 'Davis' },
        'childDateOfBirth' => '2000-01-01',
        'childSocialSecurityNumber' => '123-45-6789',
        'birthPlace' => {
          'city' => 'Anytown',
          'state' => 'WA'
        },
        'inSchool' => true,
        'seriouslyDisabled' => false,
        'hasBeenMarried' => false,
        'livesWith' => true,
        'childSupport' => 500.00
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.build_and_merge_child(child, 1)
      expect(service.fields).to include(
        'NAME_OF_CHILD_1' => 'Emily C Davis',
        'FIRST_NAME_OF_CHILD_1' => 'Emily',
        'MID_INT_OF_CHILD_1' => 'C',
        'LAST_NAME_OF_CHILD_1' => 'Davis',
        'DATE_OF_BIRTH_CHILD_1' => '01/01/2000',
        'CHILD_1_SSN' => '123-45-6789',
        'PLACE_OF_BIRTH_CHILD_1' => 'Anytown, WA',
        'CHILD_1_18_TO_23' => true,
        'CHILD_1_DISABLED' => false,
        'CHILD_1_PREV_MARRIED' => false,
        'CB_CHILD1_LIVE_WITH_OTHERS' => true,
        'AMNT_CONTRIBUTE_TO_CHILD_1' => '$500.00'
      )
    end
  end

  describe '#format_birth_place' do
    describe 'when birth place has city and state' do
      it 'formats birth place correctly' do
        birth_place = { 'city' => 'Anytown', 'state' => 'WA' }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
        expect(service.format_birth_place(birth_place)).to eq('Anytown, WA')
      end
    end

    describe 'when birth place has city and country' do
      it 'formats birth place correctly' do
        birth_place = { 'city' => 'Cette-Ville', 'country' => 'FR' }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
        expect(service.format_birth_place(birth_place)).to eq('Cette-Ville, FR')
      end
    end
  end
end
