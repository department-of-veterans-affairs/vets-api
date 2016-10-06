# frozen_string_literal: true
require 'rails_helper'
require 'mvi/mock_service'
require 'mvi/messages/find_candidate_message'

describe MVI::MockService do
  it 'loads the yaml file only once' do
    expect(YAML).to receive(:load_file).once.and_return('some yaml')
    MVI::MockService.mocked_responses
    MVI::MockService.mocked_responses
  end
  it 'returns YAML hash for find_candidate' do
    allow(MVI::MockService).to receive(:mocked_responses)
      .and_return(
        'find_candidate' => {
          'birth_date' => '19800101',
          'edipi' => '1234^NI^200DOD^USDOD^A',
          'family_name' => 'Smith',
          'gender' => 'M',
          'given_names' => %w(John William),
          'icn' => '1000123456V123456^NI^200M^USVHA^P',
          'mhv_id' => '123456^PI^200MHV^USVHA^A',
          'ssn' => '555-44-3333',
          'status' => 'active'
        }
      )
    message = double(MVI::Messages::FindCandidateMessage)
    response = MVI::MockService.find_candidate(message)
    expect(response).to eq(
      'birth_date' => '19800101',
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
