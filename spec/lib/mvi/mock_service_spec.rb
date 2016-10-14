# frozen_string_literal: true
require 'rails_helper'
require 'mvi/mock_service'
require 'mvi/messages/find_candidate_message'

describe MVI::MockService do
  let(:response_hash) do
    {
      'find_candidate' => {
        'birth_date' => '19800101',
        'edipi' => '1234^NI^200DOD^USDOD^A',
        'family_name' => 'Smith',
        'gender' => 'M',
        'given_names' => %w(John William),
        'icn' => '1000123456V123456^NI^200M^USVHA^P',
        'mhv_id' => '123456^PI^200MHV^USVHA^A',
        'vba_corp_id' => '12345678^PI^200CORP^USVBA^A',
        'ssn' => '555-44-3333',
        'status' => 'active'
      }
    }
  end
  it 'loads the yaml file only once' do
    expect(YAML).to receive(:load_file).once.and_return('some yaml')
    MVI::MockService.mocked_responses
    MVI::MockService.mocked_responses
  end
  it 'returns YAML hash with indifferent access for find_candidate' do
    allow(MVI::MockService).to receive(:mocked_responses).and_return(response_hash)
    message = double(MVI::Messages::FindCandidateMessage)
    response = MVI::MockService.find_candidate(message)

    expect(response[:birth_date]).to eq(response_hash.dig('find_candidate', 'birth_date'))
    expect(response[:edipi]).to eq(response_hash.dig('find_candidate', 'edipi'))
    expect(response[:family_name]).to eq(response_hash.dig('find_candidate', 'family_name'))
    expect(response[:gender]).to eq(response_hash.dig('find_candidate', 'gender'))
    expect(response[:given_names]).to eq(response_hash.dig('find_candidate', 'given_names'))
    expect(response[:icn]).to eq(response_hash.dig('find_candidate', 'icn'))
    expect(response[:mhv_id]).to eq(response_hash.dig('find_candidate', 'mhv_id'))
    expect(response[:vba_corp_id]).to eq(response_hash.dig('find_candidate', 'vba_corp_id'))
    expect(response[:ssn]).to eq(response_hash.dig('find_candidate', 'ssn'))
    expect(response[:status]).to eq(response_hash.dig('find_candidate', 'status'))
  end
end
