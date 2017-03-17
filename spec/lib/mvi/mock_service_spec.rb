# frozen_string_literal: true
require 'rails_helper'
require 'mvi/mock_service'
require 'mvi/service'
require 'mvi/messages/find_profile_message'

describe MVI::MockService do

  describe '#mocked_responses' do
    it 'loads the yaml file only once' do
      expect(YAML).to receive(:load_file).once.and_return('some yaml')
      subject.mocked_responses
      subject.mocked_responses
    end
  end

  describe '.find_profile' do
    let(:mvi_profile) { build(:mvi_profile) }
    let(:user) { build(:loa3_user, ssn: mvi_profile.ssn) }
    let(:yaml_hash) do
      {
        'find_candidate' => {
          mvi_profile.ssn => {
            'birth_date' => mvi_profile.birth_date,
            'edipi' => mvi_profile.edipi,
            'family_name' => mvi_profile.family_name,
            'gender' => mvi_profile.gender,
            'given_names' => mvi_profile.given_names,
            'icn' => mvi_profile.icn,
            'mhv_id' => mvi_profile.mhv_ids.first,
            'ssn' => mvi_profile.ssn
          }
        }
      }
    end

    before(:each) do
      allow(subject).to receive(:mocked_responses).and_return(yaml_hash)
    end

    it 'returns a response with a profile that matches the ssn' do
      response = subject.find_profile(user)
      expect(response.profile.given_names).to eq(mvi_profile.given_names)
      expect(response.profile.ssn).to eq(mvi_profile.ssn)
    end

    context 'when SSN lookup fails' do
      let(:user) { build(:loa3_user, ssn: '111223333') }

      it 'invokes the real service' do
        expect(subject).to receive(:find_profile).once
        subject.find_profile(user)
      end

      context 'when the real service raises an error' do
        it 'logs and re-raises an error' do
          allow_any_instance_of(MVI::Service).to receive(:find_profile).and_raise(Common::Client::Errors::HTTPError)
          expected_message = "No user found by key #{user.ssn} in mock_mvi_responses.yml, "\
            'the remote service was invoked but received an error: Common::Client::Errors::HTTPError'
          expect(Rails.logger).to receive(:error).with(expected_message)
          expect { subject.find_profile(user) }.to raise_error(Common::Client::Errors::HTTPError)
        end
      end
    end
  end
end
