# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_03'

RSpec.describe SurvivorsBenefits::StructuredData::Section03 do
  describe '#build_section3' do
    it 'calls merge_vet_aliases' do
      form = { 'veteranPreviousNames' => [{ 'first' => 'Johnny', 'last' => 'Doe' }] }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_vet_aliases).with(form['veteranPreviousNames'])
      service.build_section3
    end

    it 'calls merge_service_branch_fields' do
      form = { 'serviceBranch' => 'spaceForce' }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_service_branch_fields).with(form['serviceBranch'])
      service.build_section3
    end

    it 'merges service info fields' do
      form = {
        'activeServiceDateRange' => { 'from' => '1965-01-01', 'to' => '1975-01-01' },
        'placeOfSeparation' => 'Anytown, CA',
        'nationalGuardActivated' => true,
        'nationalGuardActivationDate' => '1965-01-01',
        'unitNameAndAddress' => 'Unit 123, 456 Military Rd, Anytown, USA',
        'unitPhone' => '555-987-6543',
        'pow' => true,
        'powDateRange' => { 'from' => '1967-01-01', 'to' => '1968-01-01' }
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section3
      expect(service.fields).to include(
        'DATE_ENTERED_TO_SERVICE' => '01/01/1965',
        'DATE_SEPARATED_FROM_SERVICE' => '01/01/1975',
        'PLACE_SEPARATED_FROM_SERVICE_1' => 'Anytown, CA',
        'ACTIVATED_TO_FED_DUTY_YES' => true,
        'ACTIVATED_TO_FED_DUTY_NO' => false,
        'DATE_OF_ACTIVATION' => '01/01/1965',
        'NAME_ADDRESS_RESERVE_UNIT' => 'Unit 123, 456 Military Rd, Anytown, USA',
        'RESERVE_PHONE_NUMBER' => '555-987-6543',
        'POW_YES' => true,
        'POW_NO' => false,
        'DATE_OF_CONFINEMENT_START' => '01/01/1967',
        'DATE_OF_CONFINEMENT_END' => '01/01/1968'
      )
    end
  end

  describe '#merge_vet_aliases' do
    it 'merges veteran alias fields' do
      form = {
        'veteranPreviousNames' => [{ 'first' => 'Johnny', 'last' => 'Doe' }, { 'first' => 'J', 'last' => 'Doe' }]
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.merge_vet_aliases(form['veteranPreviousNames'])
      expect(service.fields).to include(
        'VET_NAME_OTHER_Y' => true,
        'VET_NAME_OTHER_N' => false,
        'VET_NAME_OTHER_1' => 'Johnny Doe',
        'VET_NAME_OTHER_2' => 'J Doe'
      )
    end
  end

  describe '#merge_service_branch_fields' do
    service_branches ={
      'army' => 'ARMY',
      'navy' => 'NAVY',
      'airForce' => 'AIR-FORCE',
      'marineCorps' => 'MARINE',
      'coastGuard' => 'COAST-GUARD',
      'spaceForce' => 'SPACE',
      'noaa' => 'NOAA',
      'usphs' => 'USPHS'
    }
    service_branches.each do |branch, branch_titleized|
      it "merges service branch fields for #{branch}" do
        form = { 'serviceBranch' => branch }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_service_branch_fields(form['serviceBranch'])
        expect(service.fields["BRANCH_OF_SERVICE_#{branch_titleized}"]).to be(true)
      end
    end
    it 'merges all service branch fields' do
      form = { 'serviceBranch' => 'navy' }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.merge_service_branch_fields(form['serviceBranch'])
      expect(service.fields).to include(
        'BRANCH_OF_SERVICE_ARMY' => false,
        'BRANCH_OF_SERVICE_NAVY' => true,
        'BRANCH_OF_SERVICE_AIR-FORCE' => false,
        'BRANCH_OF_SERVICE_MARINE' => false,
        'BRANCH_OF_SERVICE_COAST-GUARD' => false,
        'BRANCH_OF_SERVICE_SPACE' => false,
        'BRANCH_OF_SERVICE_NOAA' => false,
        'BRANCH_OF_SERVICE_USPHS' => false
      )
    end
  end
end
