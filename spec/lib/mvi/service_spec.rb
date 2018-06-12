# frozen_string_literal: true

require 'rails_helper'
require 'mvi/service'
require 'mvi/responses/find_profile_response'

describe MVI::Service do
  let(:user_hash) do
    {
      first_name: 'Mitchell',
      last_name: 'Jenkins',
      middle_name: 'G',
      birth_date: '1949-03-04',
      ssn: '796122306'
    }
  end

  let(:user) { build(:user, :loa3, user_hash) }
  let(:icn_with_aaid) { '1008714701V416111^NI^200M^USVHA^P' }

  let(:mvi_profile) do
    build(
      :mvi_profile_response,
      :missing_attrs,
      :address_austin,
      given_names: %w[Mitchell G],
      vha_facility_ids: [],
      sec_id: nil,
      historical_icns: nil,
      icn_with_aaid: icn_with_aaid
    )
  end

  describe '.find_profile with icn', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
    before(:each) do
      expect(MVI::Messages::FindProfileMessageIcn).to receive(:new).once.and_call_original
    end

    context 'valid requests' do
      it 'fetches profile when icn has ^NI^200M^USVHA^P' do
        allow(user).to receive(:mhv_icn).and_return('1008714701V416111^NI^200M^USVHA^P')

        VCR.use_cassette('mvi/find_candidate/valid_icn_full') do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(mvi_profile)
        end
      end

      it 'fetches profile when icn has ^NI' do
        allow(user).to receive(:mhv_icn).and_return('1008714701V416111^NI')

        VCR.use_cassette('mvi/find_candidate/valid_icn_ni_only') do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(mvi_profile)
        end
      end

      it 'fetches profile when icn is just basic icn' do
        allow(user).to receive(:mhv_icn).and_return('1008714701V416111')

        VCR.use_cassette('mvi/find_candidate/valid_icn_without_ni') do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(mvi_profile)
        end
      end

      it 'correctly parses vet360 id if it exists', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
        allow(user).to receive(:mhv_icn).and_return('1008787551V609092^NI^200M^USVHA^P')

        VCR.use_cassette('mvi/find_candidate/valid_vet360_id') do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile['vet360_id']).to eq('123456789')
        end
      end

      it 'fetches historical icns if they exist', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
        allow(user).to receive(:mhv_icn).and_return('1008787551V609092^NI^200M^USVHA^P')
        allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')

        match = { match_requests_on: %i[method uri headers body] }
        VCR.use_cassette('mvi/find_candidate/historical_icns_with_icn', match) do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile['historical_icns']).to eq(%w[1008692852V724999 1008787485V229771])
        end
      end

      it 'fetches no historical icns if none exist', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
        allow(user).to receive(:mhv_icn).and_return('1008710003V120120^NI^200M^USVHA^P')
        allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')

        VCR.use_cassette('mvi/find_candidate/historical_icns_empty', VCR::MATCH_EVERYTHING) do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile['historical_icns']).to eq([])
        end
      end
    end

    context 'invalid requests' do
      it 'responds with a SERVER_ERROR if ICN is invalid' do
        allow(user).to receive(:mhv_icn).and_return('invalid-icn-is-here^NI')
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI Invalid Request (Possible RecordNotFound)', :error
        )

        VCR.use_cassette('mvi/find_candidate/invalid_icn') do
          expect(subject.find_profile(user))
            .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
        end
      end

      it 'responds with a SERVER_ERROR if ICN has no matches' do
        allow(user).to receive(:mhv_icn).and_return('1008714781V416999')
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI Invalid Request (Possible RecordNotFound)', :error
        )

        VCR.use_cassette('mvi/find_candidate/icn_not_found') do
          expect(subject.find_profile(user))
            .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
        end
      end
    end
  end

  describe '.find_profile without icn' do
    context 'valid request' do
      before(:each) do
        expect(MVI::Messages::FindProfileMessage).to receive(:new).once.and_call_original
      end

      it 'calls the find_profile endpoint with a find candidate message' do
        VCR.use_cassette('mvi/find_candidate/valid') do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(mvi_profile)
        end
      end

      context 'with historical icns' do
        let(:user_hash) do
          {
            first_name: 'RFIRST',
            last_name: 'RLAST',
            birth_date: '19790812',
            gender: 'M',
            ssn: '768598574'
          }
        end

        it 'fetches historical icns when available', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
          allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')

          VCR.use_cassette('mvi/find_candidate/historical_icns_with_traits', VCR::MATCH_EVERYTHING) do
            response = subject.find_profile(user)
            expect(response.status).to eq('OK')
            expect(response.profile['historical_icns']).to eq(%w[1008692852V724999 1008787485V229771])
          end
        end
      end

      context 'without gender' do
        let(:user_hash) do
          {
            first_name: 'Mitchell',
            last_name: 'Jenkins',
            middle_name: 'G',
            birth_date: '1949-03-04',
            ssn: '796122306',
            gender: nil
          }
        end

        it 'calls the find_profile endpoint with a find candidate message' do
          VCR.use_cassette('mvi/find_candidate/valid_no_gender') do
            response = subject.find_profile(user)
            expect(response.profile).to have_deep_attributes(mvi_profile)
          end
        end
      end
    end

    context 'when a MVI invalid request response is returned' do
      it 'should raise a invalid request error' do
        invalid_xml = File.read('spec/support/mvi/find_candidate_invalid_request.xml')
        allow_any_instance_of(MVI::Service).to receive(:create_profile_message).and_return(invalid_xml)
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI Invalid Request', :error
        )
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
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI Failed Request', :error
        )
        VCR.use_cassette('mvi/find_candidate/failure') do
          expect(subject.find_profile(user))
            .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
        end
      end
    end

    context 'with an MVI timeout' do
      let(:base_path) { MVI::Configuration.instance.base_path }
      it 'should raise a service error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(Rails.logger).to receive(:error).with('MVI find_profile error: Gateway timeout')
        expect(subject.find_profile(user))
          .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
      end
    end

    context 'when a status of 500 is returned' do
      it 'should raise a request failure error' do
        allow_any_instance_of(MVI::Service).to receive(:create_profile_message).and_return('<nobeuno></nobeuno>')
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI find_profile error: SOAP HTTP call failed',
          :error
        )
        VCR.use_cassette('mvi/find_candidate/five_hundred') do
          expect(subject.find_profile(user))
            .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
        end
      end
    end

    context 'when no subject is returned in the response body' do
      before(:each) do
        expect(MVI::Messages::FindProfileMessage).to receive(:new).once.and_call_original
      end

      let(:user_hash) do
        {
          first_name: 'Earl',
          last_name: 'Stephens',
          middle_name: 'M',
          birth_date: '1978-06-11',
          ssn: '796188587'
        }
      end

      it 'returns not found, does not log sentry' do
        VCR.use_cassette('mvi/find_candidate/no_subject') do
          expect(subject).not_to receive(:log_message_to_sentry)
          expect(subject.find_profile(user)).to have_deep_attributes(MVI::Responses::FindProfileResponse.with_not_found)
        end
      end

      context 'with an invalid historical icn user' do
        let(:user_hash) do
          {
            first_name: 'sdf',
            last_name: 'sdgsdf',
            birth_date: '19800812',
            gender: 'M',
            ssn: '111222333'
          }
        end

        it 'returns not found for COMP2 requests, does not log sentry', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
          allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')

          VCR.use_cassette('mvi/find_candidate/historical_icns_user_not_found', VCR::MATCH_EVERYTHING) do
            expect(subject).not_to receive(:log_message_to_sentry)
            expect(subject.find_profile(user)).to have_deep_attributes(
              MVI::Responses::FindProfileResponse.with_not_found
            )
          end
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
      before(:each) do
        expect(MVI::Messages::FindProfileMessage).to receive(:new).once.and_call_original
      end

      it 'raises an Common::Client::Errors::HTTPError' do
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI find_profile error: SOAP service returned internal server error',
          :error
        )
        VCR.use_cassette('mvi/find_candidate/internal_server_error') do
          expect(subject.find_profile(user))
            .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
        end
      end
    end

    context 'when MVI multiple match failure response' do
      before(:each) do
        expect(MVI::Messages::FindProfileMessage).to receive(:new).once.and_call_original
      end

      it 'raises MVI::Errors::RecordNotFound' do
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI Duplicate Record', :warn
        )

        VCR.use_cassette('mvi/find_candidate/failure_multiple_matches') do
          expect(subject.find_profile(user)).to have_deep_attributes(MVI::Responses::FindProfileResponse.with_not_found)
        end
      end
    end
  end

  describe '.find_profile monitoring' do
    context 'with a successful request' do
      it 'should increment find_profile total' do
        allow(user).to receive(:mhv_icn)

        allow(StatsD).to receive(:increment)
        VCR.use_cassette('mvi/find_candidate/valid') do
          subject.find_profile(user)
        end
        expect(StatsD).to have_received(:increment).with('api.mvi.find_profile.total')
      end
    end

    context 'with an unsuccessful request' do
      it 'should increment find_profile fail and total' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(StatsD).to receive(:increment).once.with(
          'api.mvi.find_profile.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.mvi.find_profile.total')
        expect(subject.find_profile(user))
          .to have_deep_attributes(MVI::Responses::FindProfileResponse.with_server_error)
      end
    end
  end
end
