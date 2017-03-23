# frozen_string_literal: true
require 'rails_helper'
require 'mvi/service'
require 'mvi/responses/find_profile_response'

describe MVI::Service do
  let(:user) do
    user_hash = {
      first_name: 'Mitchell',
      last_name: 'Jenkins',
      middle_name: 'G',
      birth_date: '1949-03-04',
      ssn: '796122306'
    }
    build(:loa3_user, user_hash)
  end
  let(:mvi_profile) do
    build(:mvi_profile_response, :missing_attrs, :address_austin, given_names: %w(Mitchell G))
  end

  describe '.find_profile' do
    context 'with a valid request' do
      it 'calls the find_profile endpoint with a find candidate message' do
        VCR.use_cassette('mvi/find_candidate/valid') do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(mvi_profile)
        end
      end
    end

    context 'with a valid request without gender' do
      let(:user) do
        user_hash = {
          first_name: 'Mitchell',
          last_name: 'Jenkins',
          middle_name: 'G',
          birth_date: '1949-03-04',
          ssn: '796122306',
          gender: nil
        }
        build(:loa3_user, user_hash)
      end

      it 'calls the find_profile endpoint with a find candidate message' do
        VCR.use_cassette('mvi/find_candidate/valid_no_gender') do
          response = subject.find_profile(user)
          expect(response.profile).to have_deep_attributes(mvi_profile)
        end
      end
    end

    context 'when a MVI invalid request response is returned' do
      it 'should raise a invalid request error' do
        invalid_xml = File.read('spec/support/mvi/find_candidate_invalid_request.xml')
        allow_any_instance_of(MVI::Service).to receive(:create_profile_message).and_return(invalid_xml)
        VCR.use_cassette('mvi/find_candidate/invalid') do
          expect(subject.find_profile(user))
            .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
        end
      end
    end

    context 'when a MVI failure response is returned' do
      it 'should raise a request failure error' do
        invalid_xml = File.read('spec/support/mvi/find_candidate_invalid_request.xml')
        allow_any_instance_of(MVI::Service).to receive(:create_profile_message).and_return(invalid_xml)
        VCR.use_cassette('mvi/find_candidate/failure') do
          expect(subject.find_profile(user))
            .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
        end
      end
    end

    context 'with an MVI timeout' do
      it 'should raise a service error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(Rails.logger).to receive(:error).with('MVI find_profile error: timeout')
        expect(subject.find_profile(user))
          .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
      end
    end

    context 'when a status of 500 is returned' do
      it 'should raise a request failure error' do
        allow_any_instance_of(MVI::Service).to receive(:create_profile_message).and_return('<nobeuno></nobeuno>')
        VCR.use_cassette('mvi/find_candidate/five_hundred') do
          expect(subject.find_profile(user))
            .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
        end
      end
    end

    context 'when no subject is returned in the response body' do
      let(:user) do
        user_hash = {
          first_name: 'Earl',
          last_name: 'Stephens',
          middle_name: 'M',
          birth_date: '1978-06-11',
          ssn: '796188587'
        }
        build(:loa3_user, user_hash)
      end
      it 'raises an MVI::Errors::RecordNotFound error' do
        VCR.use_cassette('mvi/find_candidate/no_subject') do
          expect(subject.find_profile(user)).to have_deep_attributes(MVI::Responses::FindProfileResponse.with_not_found)
        end
      end

      context 'with an ongoing breakers outage' do
        it 'returns the correct thing' do
          MVI::Configuration.instance.breakers_service.begin_forced_outage!
          expect { subject.find_profile(user) }.to raise_error(Breakers::OutageException)
        end
      end
    end

    context 'when MVI returns 500 but VAAFI sends 200' do
      it 'raises an Common::Client::Errors::HTTPError' do
        VCR.use_cassette('mvi/find_candidate/internal_server_error') do
          expect(subject.find_profile(user))
            .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
        end
      end
    end

    context 'when MVI multiple match failure response' do
      it 'raises MVI::Errors::RecordNotFound' do
        VCR.use_cassette('mvi/find_candidate/failure_multiple_matches') do
          expect(subject.find_profile(user)).to have_deep_attributes(MVI::Responses::FindProfileResponse.with_not_found)
        end
      end
    end
  end
end
