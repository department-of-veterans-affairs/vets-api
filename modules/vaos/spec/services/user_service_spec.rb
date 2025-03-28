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

  let(:expected_sts_token) do
    {
      access_token:
      'eyJhbGciOiJSUzUxMiJ9.eyJhdXRoZW50aWNhdGVkIjp0cnVlLCJzdWIiOiIxMDEyODQ2MDQzVjU3NjM0MSIsImF1dGhlbnRpY2F0aW9uQXV0' \
      'aG9yaXR5IjoiZ292LnZhLm1vYmlsZS5vYXV0aC52MSIsImlkVHlwZSI6ImljbiIsImlzcyI6Imdvdi52YS52YW1mLnVzZXJzZXJ2aWNlLnYyI' \
      'iwib25CZWhhbGZPZiI6eyJpZCI6IjEwMTI4NDYwNDNWNTc2MzQxIiwiaWRUeXBlIjoiaWNuIiwicmVwcmVzZW50YXRpdmVJZCI6Ijc0YjMxND' \
      'VlMTM1NDU1NWUiLCJyZXByZXNlbnRhdGl2ZUlkVHlwZSI6Im1vYmlsZS1vYXV0aC1zdHMtY2xpZW50LWlkIiwicmVwcmVzZW50YXRpdmVOYW1' \
      'lIjoiVkEuZ292IEFwcG9pbnRtZW50cyAoU1FBKSJ9LCJ2YW1mLmF1dGgucmVzb3VyY2VzIjpbIl4uKigvKT9wYXRpZW50W3NdPy9FRElQSS8x' \
      'MDEzNTk5NzMwKC8uKik_JCIsIl4uKigvKT9wYXRpZW50W3NdPy8oSUNOLyk_MTAxMjg0NjA0M1Y1NzYzNDEoLy4qKT8kIiwiXi4qKC8pP3Npd' \
      'GVbc10_LyhkZm4tKT85ODMvcGF0aWVudFtzXT8vNzIxNjY4NS9hcHBvaW50bWVudHMoLy4qKT8kIiwiXi4qKC8pP3NpdGVbc10_LyhkZm4tKT' \
      '82NjgvcGF0aWVudFtzXT8vMTYxNzM3L2FwcG9pbnRtZW50cygvLiopPyQiLCJeLiooLyk_c2l0ZVtzXT8vKGRmbi0pPzk4NC9wYXRpZW50W3N' \
      'dPy81NTIxNjEwNDQvYXBwb2ludG1lbnRzKC8uKik_JCJdLCJ2ZXJzaW9uIjoyLjgsInZpc3RhSWRzIjpbeyJzaXRlSWQiOiI5ODMiLCJwYXRp' \
      'ZW50SWQiOiI3MjE2Njg1In0seyJzaXRlSWQiOiI5ODQiLCJwYXRpZW50SWQiOiI1NTIxNjEwNDQifSx7InNpdGVJZCI6IjY2OCIsInBhdGllb' \
      'nRJZCI6IjE2MTczNyJ9XSwiYXVkIjoiNzRiMzE0NWUxMzU0NTU1ZSIsIm5iZiI6MTcxMDQyNDAxOSwic3N0IjoxNzEwNDI0MTk5LCJwYXRpZW' \
      '50Ijp7ImZpcnN0TmFtZSI6IkpBQ1FVRUxJTkUiLCJtaWRkbGVOYW1lIjoiSyIsImxhc3ROYW1lIjoiTU9SR0FOIiwiZGF0ZU9mQmlydGgiOiI' \
      'xOTYyLTAyLTA3IiwiZ2VuZGVyIjoiRiIsInNzbiI6Ijc5NjAyOTE0NiIsImljbiI6IjEwMTI4NDYwNDNWNTc2MzQxIiwiZWRpcGlkIjoiMTAx' \
      'MzU5OTczMCJ9LCJhdHRyaWJ1dGVzIjp7InZhX2VhdXRoX3NlY2lkIjoiMDAwMDAyODEyMSJ9LCJ2YW1mLmF1dGgucm9sZXMiOlsidmV0ZXJhb' \
      'iJdLCJ1c2VyVHlwZSI6Im9uLWJlaGFsZi1vZiIsImV4cCI6MTcxMDQyNTA5OSwiaWF0IjoxNzEwNDI0MTk5LCJqdGkiOiI3Y2UzNjBmZi1jNW' \
      'E0LTQ0NmUtYmU0OC04NmZiMjc1OWMzNmQifQ.Kd_6NlaNnjtWk0RBgwDKTjbrLL0oo18DQ753-crp4LuDcWy_370s5PLQCjyo7EUwoGOieAsp' \
      'SsYaPmZQ_bghzI1W1MXtUJWVOOTgJIAcESsfquXGj7-0QXxTT4rHSaL8oBRVt6UqfI9exEPmfjM58ibJY2ECVTUdaScJaT1BXShiwTDEqC5bn' \
      'ApUvAMUzEHi8dx48EIMbqNLYgUZT3GCtMs0xIP9wGjt6JK0l-UDOn0aK3b-fJUF-ZcerYdY2opUJuu5oQrDaOocbRqrwBlCFqa1oUTCxLYLV6' \
      '9cuaSOQfXqTIoWuvbj-7FSFhF1nc2lhgjOWckJ740vzINYZ_uQNA',
      expiration: 15.minutes.from_now
    }
  end

  before do
    allow(VAOS::Configuration.instance).to receive(:rsa_key).and_return(rsa_key)
    Rails.cache.clear
    time = Time.utc(2019, 10, 10, 18, 14, 56)
    Timecop.freeze(time)
  end

  after { Timecop.return }

  describe '#session' do
    context 'when a successful request to the Mobile OAuth Secure Token Service is made' do
      before do
        allow_any_instance_of(MAP::SecurityToken::Service).to receive(:token).and_return(expected_sts_token)
      end

      it 'returns the session token' do
        expect(subject.session(user)).to eq(expected_sts_token[:access_token])
      end

      it 'saves the session token in the cache' do
        subject.session(user)
        token = Oj.load($redis.get("va-mobile-session:#{user.account_uuid}"))[:token]

        expect(token).to eq(expected_sts_token[:access_token])
      end
    end
  end

  context 'when a request to the Mobile OAuth Secure Token Service fails' do
    before do
      allow_any_instance_of(MAP::SecurityToken::Service).to receive(:token)
        .and_raise(Common::Client::Errors::ClientError)
    end

    it 'raises a Common::Client::Errors::ClientError' do
      expect { subject.session(user) }.to raise_error(
        Common::Client::Errors::ClientError
      )
    end
  end

  describe '#expiring_soon?' do
    let(:valid_token) { JWT.encode({ exp: (Time.now.utc + 3.minutes).to_i }, nil) }
    let(:expiring_token) { JWT.encode({ exp: (Time.now.utc + 1.minute).to_i }, nil) }
    let(:falsely_encoded_token) { 'not a real token' }

    context 'when the token is valid and not expiring soon' do
      it 'returns false' do
        expect(subject.send(:expiring_soon?, valid_token)).to be false
      end
    end

    context 'when the token is valid but expiring soon' do
      it 'returns true' do
        expect(subject.send(:expiring_soon?, expiring_token)).to be true
      end
    end

    context 'when the token is not valid' do
      it 'logs an error and returns true' do
        expect(Rails.logger).to receive(:error).with(/VAOS Error decoding JWT/)
        expect(subject.send(:expiring_soon?, falsely_encoded_token)).to be true
      end
    end
  end
end
