# frozen_string_literal: true
require 'rails_helper'
require 'mvi/service'
require 'mvi/responses/find_profile_response'

describe MVI::Service do
  let(:user) do
    build(:loa3_user,
      first_name: 'Mitchell',
      last_name: 'Jenkins',
      middle_name: 'G',
      birth_date: '1949-03-04',
      ssn: '796122306'
    )
  end
  let(:mvi_profile) { build(:mvi_profile_missing_attrs, given_names: %w(Mitchell G), mhv_ids: nil) }

  describe '.find_profile' do
    context 'with a valid request' do
      it 'calls the find_profile endpoint with a find candidate message' do
        VCR.use_cassette('mvi/find_profile/valid') do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(mvi_profile)
        end
      end
    end

    context 'with a valid request without gender' do
      let(:user) do
        FactoryGirl.build(
          :user,
          first_name: 'Mitchell',
          last_name: 'Jenkins',
          middle_name: 'G',
          birth_date: '1949-03-04',
          ssn: '796122306',
          gender: nil
        )
      end
      let(:message) do
        MVI::Messages::FindProfileMessage.new(
          [user.first_name, user.middle_name], user.last_name, user.birth_date, user.ssn, user.gender
        )
      end
      it 'calls the find_profile endpoint with a find candidate message' do
        VCR.use_cassette('mvi/find_profile/valid_no_gender') do
          response = subject.find_profile(message)
          expect(response).to eq(
            edipi: nil,
            icn: '1008714701V416111^NI^200M^USVHA^P',
            mhv_ids: nil,
            vba_corp_id: '9100792239^PI^200CORP^USVBA^A',
            active_status: 'active',
            given_names: %w(Mitchell G),
            family_name: 'Jenkins',
            gender: 'M',
            birth_date: '19490304',
            ssn: '796122306',
            address: {
              street_address_line: '121 A St',
              city: 'Austin',
              state: 'TX',
              postal_code: '78772',
              country: 'USA'
            },
            suffix: nil,
            home_phone: nil
          )
        end
      end
    end

    context 'when a MVI invalid request response is returned' do
      it 'should raise a invalid request error' do
        invalid_xml = File.read('spec/support/mvi/find_profile_invalid_request.xml')
        allow(message).to receive(:to_xml).and_return(invalid_xml)
        VCR.use_cassette('mvi/find_profile/invalid') do
          expect { subject.find_profile(message) }.to raise_error(MVI::Errors::InvalidRequestError)
        end
      end
    end

    context 'when a MVI failure response is returned' do
      it 'should raise a request failure error' do
        invalid_xml = File.read('spec/support/mvi/find_profile_invalid_request.xml')
        allow(message).to receive(:to_xml).and_return(invalid_xml)
        VCR.use_cassette('mvi/find_profile/failure') do
          expect { subject.find_profile(message) }.to raise_error(MVI::Errors::RequestFailureError)
        end
      end
    end

    context 'with an MVI timeout' do
      it 'should raise a service error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(Rails.logger).to receive(:error).with('MVI find_profile error: timeout')
        expect { subject.find_profile(message) }.to raise_error(MVI::Errors::ServiceError)
      end
    end

    context 'when a status of 500 is returned' do
      it 'should raise a request failure error' do
        allow(message).to receive(:to_xml).and_return('<nobeuno></nobeuno>')
        VCR.use_cassette('mvi/find_profile/five_hundred') do
          expect { subject.find_profile(message) }.to raise_error(MVI::Errors::ServiceError)
        end
      end
    end

    context 'when no subject is returned in the response body' do
      let(:user) do
        FactoryGirl.build(
          :user,
          first_name: 'Earl',
          last_name: 'Stephens',
          middle_name: 'M',
          birth_date: '1978-06-11',
          ssn: '796188587'
        )
      end
      let(:message) do
        MVI::Messages::FindProfileMessage.new(
          [user.first_name, user.middle_name], user.last_name, user.birth_date, user.ssn, user.gender
        )
      end
      it 'raises an MVI::Errors::RecordNotFound error' do
        VCR.use_cassette('mvi/find_profile/no_subject') do
          expect { subject.find_profile(message) }.to raise_error(MVI::Errors::RecordNotFound)
        end
      end

      context 'with an ongoing breakers outage' do
        it 'returns the correct thing' do
          MVI::Configuration.instance.breakers_service.begin_forced_outage!
          expect { subject.find_profile(message) }.to raise_error(Breakers::OutageException)
        end
      end
    end

    context 'when MVI returns 500 but VAAFI sends 200' do
      it 'raises an Common::Client::Errors::HTTPError' do
        VCR.use_cassette('mvi/find_profile/internal_server_error') do
          expect do
            subject.find_profile(message)
          end.to raise_error(MVI::Errors::ServiceError)
        end
      end
    end

    context 'when MVI multiple match failure response' do
      it 'raises MVI::Errors::RecordNotFound' do
        VCR.use_cassette('mvi/find_profile/failure_multiple_matches') do
          expect do
            subject.find_profile(message)
          end.to raise_error(MVI::Errors::RecordNotFound)
        end
      end
    end
  end
end
