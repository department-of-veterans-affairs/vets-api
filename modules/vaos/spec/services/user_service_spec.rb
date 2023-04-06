# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/fixture_helper'

describe VAOS::UserService do
  let(:user) { build(:user, :vaos, :accountable) }
  let(:subject) { described_class.new }
  let(:rsa_key) { OpenSSL::PKey::RSA.new(read_fixture_file('open_ssl_rsa_private.pem')) }

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

  let(:refresh_token) do
    'eyJhbGciOiJSUzUxMiJ9.eyJhdXRoZW50aWNhdGVkIjp0cnVlLCJzdWIiOiIxMDEyODQ1MzMxVjE1MzA0MyIsImF1dGhlbnRpY2F0aW9uQXV' \
      '0aG9yaXR5IjoiZ292LnZhLnZhb3MiLCJpZFR5cGUiOiJJQ04iLCJpc3MiOiJnb3YudmEudmFtZi51c2Vyc2VydmljZS52MSIsInZhbWYuYXV0' \
      'aC5yZXNvdXJjZXMiOlsiXi4qKFwvKT9zaXRlW3NdP1wvKGRmbi0pPzk4NFwvcGF0aWVudFtzXT9cLzU1MjE2MTA1MFwvYXBwb2ludG1lbnRzK' \
      'FwvLiopPyQiLCJeLiooXC8pP3NpdGVbc10_XC8oZGZuLSk_OTgzXC9wYXRpZW50W3NdP1wvNzIxNjY5MVwvYXBwb2ludG1lbnRzKFwvLiopPy' \
      'QiLCJeLiooXC8pP3BhdGllbnRbc10_XC8oSUNOXC8pPzEwMTI4NDUzMzFWMTUzMDQzKFwvLiopPyQiXSwidmVyc2lvbiI6Mi4xLCJ2aXN0YUl' \
      'kcyI6W3sicGF0aWVudElkIjoiNTUyMTYxMDUwIiwic2l0ZUlkIjoiOTg0In0seyJwYXRpZW50SWQiOiI3MjE2NjkxIiwic2l0ZUlkIjoiOTgz' \
      'In1dLCJzdGFmZkRpc2NsYWltZXJBY2NlcHRlZCI6dHJ1ZSwibmJmIjoxNTkyNTIyODY1LCJzc3QiOjE1OTI1MjI5NDksInBhdGllbnQiOnsia' \
      'WNuIjoiMTAxMjg0NTMzMVYxNTMwNDMifSwicmlnaHRPZkFjY2Vzc0FjY2VwdGVkIjp0cnVlLCJ2YW1mLmF1dGgucm9sZXMiOlsidmV0ZXJhbi' \
      'JdLCJleHAiOjE1OTI1MjM5NDUsImp0aSI6IjEzM2JhZjVkLWZjNjItNGY0ZS04YTkxLWY2YjE2MmQzODk0ZiIsImxvYSI6Mn0.Q0RuJojxa1X' \
      'asQGFrMD4TZJqMGPJL2Y-2S0i_PEzt7ODQXSah4MnJAbT8r48D91yvCBR8x4tMArRaO-1_SpxFKOMT-ysXqcYV-LeZyuewiuNO6c8gfVUwsOs' \
      'SF0FYY2RqV33OHEdSYQu_wMCVf-1mV5nKURQcNtaOH1vw42zruu6JUooEqSUgzLXeMmjrZVMQyeOBVHsNCV-BEIUWyPta1HcnLr-z0hyASS1Z' \
      'VpEqDzdWOaWmAgVJGj0ctyYZQG-kbLs_t36zkN8XK3HEN1-Gjy2WLGjLLlHQbG3AFHih0pyiM2NsUSJWH0_r_S2wF4h-GtXeIPckS2JfBZ0F5' \
      'HM1A'
  end

  before do
    allow(VAOS::Configuration.instance).to receive(:rsa_key).and_return(rsa_key)
    time = Time.utc(2019, 10, 10, 18, 14, 56)
    Timecop.freeze(time)
  end

  after { Timecop.return }

  describe '#session' do
    describe '#session' do
      let(:response) { double('response', body: token) }

      context 'with a 200 response' do
        it 'returns the session token' do
          VCR.use_cassette('vaos/users/post_session') do
            session_token = subject.session(user)
            expect(session_token).to be_a(String)
          end
        end

        it 'makes a call out to the the VAOS user service once' do
          VCR.use_cassette('vaos/users/post_session') do
            expect(subject).to receive(:perform).once.and_return(response)
            subject.session(user)
          end
        end

        it 'sets the cached token ttl to expire fortyfive seconds before the VAMF token expires' do
          VCR.use_cassette('vaos/users/post_session') do
            subject.session(user)
            expect($redis.ttl("va-mobile-session:#{user.account_uuid}")).to eq(855)
          end
        end
      end

      context 'with a 400 response' do
        it 'raises a client error' do
          VCR.use_cassette('vaos/users/post_session_400') do
            expect { subject.session(user) }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end

      context 'with a 403 response' do
        it 'raises a client error' do
          VCR.use_cassette('vaos/users/post_session_403') do
            expect { subject.session(user) }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end

      context 'with a blank response' do
        it 'raises a client error' do
          VCR.use_cassette('vaos/users/post_session_blank_body') do
            expect { subject.session(user) }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end
    end

    describe '#extend_session' do
      before do
        VCR.use_cassette('vaos/users/post_session') do
          subject.session(user)
        end
      end

      context 'with one call inside the original lock (< 60s)' do
        it 'does not trigger the extend session job' do
          VCR.use_cassette('vaos/users/get_user_jwts') do
            expect(VAOS::ExtendSessionJob).not_to receive(:perform_async).with(user.account_uuid)
            subject.extend_session(user.account_uuid)
          end
        end
      end

      context 'with one call outside the lock (> 60s)' do
        it 'triggers the extend session job' do
          VCR.use_cassette('vaos/users/get_user_jwts') do
            Timecop.travel(Time.zone.now + 2.minutes)
            expect(VAOS::ExtendSessionJob).to receive(:perform_async).with(user.account_uuid).once
            subject.extend_session(user.account_uuid)
          end
        end
      end

      context 'with multiple calls outside the original lock (> 60s)' do
        it 'triggers the extend session job only once' do
          VCR.use_cassette('vaos/users/get_user_jwts') do
            Timecop.travel(Time.zone.now + 2.minutes)
            expect(VAOS::ExtendSessionJob).to receive(:perform_async).with(user.account_uuid).once
            subject.extend_session(user.account_uuid)
            subject.extend_session(user.account_uuid)
          end
        end
      end
    end
  end

  describe '#update_session_token' do
    context 'with a cached token' do
      before do
        VCR.use_cassette('vaos/users/post_session') do
          subject.session(user)
        end
      end

      context 'with a 200 response' do
        it 'updates and returns the new session token' do
          VCR.use_cassette('vaos/users/get_user_jwts') do
            expect(subject.update_session_token(user.account_uuid)).to eq(refresh_token)
          end
        end
      end
    end
  end
end
