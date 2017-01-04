# frozen_string_literal: true
require 'rails_helper'
require 'mvi/mock_service'
require 'mvi/service'
require 'mvi/messages/find_candidate_message'

describe MVI::MockService do
  it 'loads the yaml file only once' do
    expect(YAML).to receive(:load_file).once.and_return('some yaml')
    subject.mocked_responses
    subject.mocked_responses
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
      allow(subject).to receive(:mocked_responses).and_return(yaml_hash)
      allow(message).to receive(:ssn).and_return('555443333')
      response = subject.find_candidate(message)
      expect(response).to eq(yaml_hash.dig('find_candidate', '555443333'))
      expect(response[:birth_date]).to eq('19800101')
    end

    context 'when SSN lookup fails' do
      let(:ssn) { '111223333' }
      before(:each) do
        allow(subject).to receive(:mocked_responses).and_return(yaml_hash)
        allow(message).to receive(:ssn).and_return(ssn)
      end

      it 'invokes the real service' do
        expect(subject).to receive(:find_candidate).once
        subject.find_candidate(message)
      end

      context 'when the real service raises an error' do
        it 'logs and re-raises an error' do
          allow_any_instance_of(MVI::Service).to receive(:find_candidate).and_raise(SOAP::Errors::HTTPError)
          expected_message = "No user found by key #{ssn} in mock_mvi_responses.yml, "\
            'the remote service was invoked but received an error: SOAP::Errors::HTTPError'
          expect(Rails.logger).to receive(:error).once.with(expected_message)
          expect { subject.find_candidate(message) }.to raise_error(SOAP::Errors::HTTPError)
        end
      end
    end
  end
end
