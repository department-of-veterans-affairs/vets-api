# frozen_string_literal: true
require 'rails_helper'
require 'mvi/mock_service'
require 'mvi/messages/find_candidate_message'

describe MVI::Service do
  it 'returns YAML hash for find_candidate' do
    response = MVI::MockService.find_candidate
    expect(response).to eq(
      'dob' => '19800101',
      'edipi' => '1234^NI^200DOD^USDOD^A',
      'family_name' => 'Smith',
      'gender' => 'M',
      'given_names' => %w(John William),
      'icn' => '1000123456V123456^NI^200M^USVHA^P',
      'mhv_id' => '123456^PI^200MHV^USVHA^A',
      'ssn' => '555-44-3333',
      'status' => 'active'
    )
  end
end
