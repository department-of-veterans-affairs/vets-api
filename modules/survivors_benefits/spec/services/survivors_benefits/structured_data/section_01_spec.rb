# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_01'

RSpec.describe SurvivorsBenefits::StructuredData::Section01 do
  describe '#build_section1' do
    it 'merges veteran ID info into the correct structured data' do
      form = {
        'veteranFullName' => {
          'first' => 'John',
          'middle' => 'A',
          'last' => 'Doe',
          'suffix' => 'Jr.'
        },
        'vaClaimsHistory' => true,
        'diedOnDuty' => false,
        'veteranSocialSecurityNumber' => '123-45-6789',
        'veteranDateOfBirth' => '1950-01-01',
        'vaFileNumber' => '123456789',
        'veteranServiceNumber' => '987654321',
        'veteranDateOfDeath' => '2020-01-01'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section1
      expect(service.fields).to include(
        'VETERAN_FIRST_NAME' => 'John',
        'VETERAN_MIDDLE_INITIAL' => 'A',
        'VETERAN_LAST_NAME' => 'Doe',
        'VETERAN_NAME' => 'John A Doe Jr.',
        'VETSPCHPAR_FILECLAIM_Y' => true,
        'VETSPCHPAR_FILECLAIM_N' => false,
        'VETDIED_ACTIVEDUTY_Y' => false,
        'VETDIED_ACTIVEDUTY_N' => true,
        'VETERAN_SSN' => '123-45-6789',
        'VETERAN_DOB' => '01/01/1950',
        'VA_FILE_NUMBER' => '123456789',
        'VETERANS_SERVICE_NUMBER' => '987654321',
        'VETERAN_DATE_OF_DEATH' => '01/01/2020'
      )
    end
  end
end
