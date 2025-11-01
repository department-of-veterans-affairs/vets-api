# frozen_string_literal: true

require_relative 'prefill'
require_relative 'military_information'

module FormProfileSpecData
  def self.v686_c_674_v2_expected(user, us_phone)
    FormPrefillSpecData.v686_c_674_v2_expected(user, us_phone)
  end

  def self.initialize_va_profile_prefill_military_information_expected
    MilitaryInformationSpecData.initialize_va_profile_prefill_military_information_expected
  end

  def self.dependents_data
    { number_of_records: '1', persons: [{
      award_indicator: 'Y',
      date_of_birth: '01/02/1960',
      email_address: 'test@email.com',
      first_name: 'JANE',
      last_name: 'WEBB',
      middle_name: 'M',
      ptcpnt_id: '600140899',
      related_to_vet: 'Y',
      relationship: 'Spouse',
      ssn: '222883214',
      veteran_indicator: 'N'
    }] }
  end

  def self.dependents_information
    [{
      'fullName' => { 'first' => 'JANE', 'middle' => 'M', 'last' => 'WEBB' },
      'dateOfBirth' => '1960-01-02',
      'ssn' => '222883214',
      'relationshipToVeteran' => 'Spouse',
      'awardIndicator' => 'Y'
    }]
  end
end
