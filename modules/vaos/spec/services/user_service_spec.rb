# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/fixture_helper'

describe VAOS::UserService do
  let(:user) { build(:user, :vaos, :accountable) }
  let(:subject) { described_class.new(user) }

  describe '#session' do
    let(:token) do
      'eyJhbGciOiJSUzUxMiJ9.eyJsYXN0TmFtZSI6Ik1vcmdhbiIsInN1YiI6IjEwMTI4NDU5NDNWOTAwNjgxIiwiYXV0aGVudGljYXRlZCI6dH' \
      'J1ZSwiYXV0aGVudGljYXRpb25BdXRob3JpdHkiOiJnb3YudmEudmFvcyIsImlkVHlwZSI6IklDTiIsImlzcyI6Imdvdi52YS52YW1mLnVzZX' \
      'JzZXJ2aWNlLnYxIiwidmFtZi5hdXRoLnJlc291cmNlcyI6WyJeLiooXC8pP3BhdGllbnRbc10_XC8oSUNOXC8pPzEwMTI4NDU5NDNWOTAwNj' \
      'gxKFwvLiopPyQiLCJeLiooXC8pP3NpdGVbc10_XC8oZGZuLSk_OTg0XC9wYXRpZW50W3NdP1wvNTUyMTYxNzMyXC9hcHBvaW50bWVudHMoXC8' \
      'uKik_JCIsIl4uKihcLyk_c2l0ZVtzXT9cLyhkZm4tKT85ODNcL3BhdGllbnRbc10_XC83MjE2NjkwXC9hcHBvaW50bWVudHMoXC8uKik_JCJd' \
      'LCJ2ZXJzaW9uIjoyLjEsInZpc3RhSWRzIjpbeyJwYXRpZW50SWQiOiI1NTIxNjE3MzIiLCJzaXRlSWQiOiI5ODQifSx7InBhdGllbnRJZCI6I' \
      'jcyMTY2OTAiLCJzaXRlSWQiOiI5ODMifV0sImZpcnN0TmFtZSI6IkNlY2lsIiwic3RhZmZEaXNjbGFpbWVyQWNjZXB0ZWQiOnRydWUsIm5iZ' \
      'iI6MTU3MDczMTExNiwicGF0aWVudCI6eyJmaXJzdE5hbWUiOiJDZWNpbCIsImxhc3ROYW1lIjoiTW9yZ2FuIiwiaWNuIjoiMTAxMjg0NTk0M' \
      '1Y5MDA2ODEifSwidXNlclR5cGUiOiJWRVRFUkFOIiwidmFtZi5hdXRoLnJvbGVzIjpbInZldGVyYW4iXSwicmlnaHRPZkFjY2Vzc0FjY2Vwd' \
      'GVkIjp0cnVlLCJleHAiOjE1NzA3MzIxOTYsImp0aSI6ImViZmM5NWVmNWYzYTQxYTdiMTVlNDMyZmU0N2U5ODY0IiwibG9hIjoyfQ.HD2xgV' \
      'YoCmF87XLlgawiCvddtkhQ0mOj7T00kh02ygY8cQhoYiylH9DaQRiFg-ymsf0xA-BHP4JqrDXLKho7wTJceRBfeYRysUSa0bbRVDPPeEuQF0' \
      'f96DCTsL_t6ZRJB72fL4yK-Z5jovGVD8yYX6Fg4j9IJhGN2ibwJwjS6bS4I7quhm_29SjRNtjgPlvM87Lz9xg3KDHjcHBfthOvhcsnvwcsQn' \
      'VKyvyM4ujy7nUqTF8qyJdFflDLC1F3KbY0W5IcJwR1R226Jp7K8tsfmWaZOWWD_1BITQBbdl-0jfgWcdpxpv67WBAkv3Lw9DN5dplOuan5Dq' \
      'N-ZTMun8ub0A'
    end
    let(:response) { double('response', body: token) }
    let(:rsa_key) { OpenSSL::PKey::RSA.new(read_fixture_file('open_ssl_rsa_private.pem')) }

    before do
      allow(VAOS::Configuration.instance).to receive(:rsa_key).and_return(rsa_key)
      time = Time.utc(2019, 10, 10, 18, 14, 56)
      Timecop.freeze(time)
    end

    after { Timecop.return }

    context 'with a 200 response' do
      it 'returns the session token' do
        VCR.use_cassette('vaos/users/post_session') do
          session_token = subject.session
          expect(session_token).to be_a(String)
        end
      end

      context 'with a cached session' do
        it 'does not call the VAOS user service' do
          VCR.use_cassette('vaos/users/post_session') do
            VAOS::SessionStore.new(account_uuid: user.account_uuid, token: token).save
            expect(subject).not_to receive(:perform)
            subject.session
          end
        end
      end

      context 'when there is no saved session token' do
        it 'makes a call out to the the VAOS user service once' do
          VCR.use_cassette('vaos/users/post_session') do
            expect(subject).to receive(:perform).once.and_return(response)
            subject.session
          end
        end

        it 'returns a token' do
          VCR.use_cassette('vaos/users/post_session') do
            expect(subject.session).to be_a(String)
          end
        end

        it 'sets the cached token ttl to expire five seconds before the VAMF token expires' do
          VCR.use_cassette('vaos/users/post_session') do
            subject.session
            expect(Redis.current.ttl("va-mobile-session:#{user.account_uuid}")).to eq(895)
          end
        end
      end

      context 'when the session is fetched before 15m' do
        it 'does not call perform to request a new token' do
          VAOS::SessionStore.new(account_uuid: user.account_uuid, token: token).save
          Timecop.travel(Time.zone.now + 11.minutes)
          VCR.use_cassette('vaos/users/post_session') do
            expect(subject).not_to receive(:perform)
            subject.session
          end
        end
      end

      context 'when the session is fetched after 15m' do
        it 'calls perform to request a new token' do
          VAOS::SessionStore.new(user_uuid: user.uuid, token: token).save
          Timecop.travel(Time.zone.now + 15.minutes)
          VCR.use_cassette('vaos/users/post_session') do
            expect(subject).to receive(:perform).once.and_return(response)
            subject.session
          end
        end
      end
    end

    context 'with a 400 response' do
      it 'raises a client error' do
        VCR.use_cassette('vaos/users/post_session_400') do
          expect { subject.session }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'with a 403 response' do
      it 'raises a client error' do
        VCR.use_cassette('vaos/users/post_session_403') do
          expect { subject.session }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'with a blank response' do
      it 'raises a client error' do
        VCR.use_cassette('vaos/users/post_session_blank_body') do
          expect { subject.session }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
