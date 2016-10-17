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

  describe '.find_candidate' do
    let(:yaml_hash) do
      {
        'find_candidate' => {
          '555443333' => {
            'birth_date' => '19800101',
            'edipi' => '1234^NI^200DOD^USDOD^A',
            'family_name' => 'Smith',
            'gender' => 'M',
            'given_names' => %w(John William),
            'icn' => '1000123456V123456^NI^200M^USVHA^P',
            'mhv_id' => '123456^PI^200MHV^USVHA^A',
            'ssn' => '555443333',
            'status' => 'active'
          }
        }
      }
    end

    let(:message) { double(MVI::Messages::FindCandidateMessage) }

    it 'returns YAML hash for find_candidate by SSN' do
      allow(MVI::MockService).to receive(:mocked_responses).and_return(yaml_hash)
      allow(message).to receive(:ssn).and_return('555443333')
      expect(MVI::MockService.find_candidate(message)).to eq(yaml_hash.dig('find_candidate', '555443333'))
    end

    it 'returns a default value if SSN lookup fails' do
      allow(MVI::MockService).to receive(:mocked_responses).and_return(yaml_hash)
      allow(message).to receive(:ssn).and_return('111223333')
      expect(MVI::MockService.find_candidate(message)).to eq(
        birth_date: '18090212',
        edipi: '1234^NI^200DOD^USDOD^A',
        family_name: 'Lincoln',
        gender: 'M',
        given_names: %w(Abraham),
        icn: '1000123456V123456^NI^200M^USVHA^P',
        mhv_id: '123456^PI^200MHV^USVHA^A',
        ssn: '272112222',
        status: 'deceased',
        vba_corp_id: '12345678^PI^200CORP^USVBA^A'
      )
    end
  end
end
