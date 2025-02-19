# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'
require_relative '../../../app/models/ccra/referral_list_entry'
require_relative '../../../app/models/ccra/referral_detail'

describe Ccra::ReferralService do
  subject { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234', flipper_id: '1234') }
  let(:jwt_token) { 'fake-jwt-token' }
  let(:access_token) { 'fake-access-token' }

  before do
    allow(RequestStore.store).to receive(:[]).with('request_id').and_return('request-id')
    allow_any_instance_of(Concerns::JwtWrapper).to receive(:sign_assertion).and_return(jwt_token)
    allow(Flipper).to receive(:enabled?).with(VAOS::SessionService::STS_OAUTH_TOKEN, user).and_return(true)

    # Allow any cache fetch call to return the access token if it matches our key, otherwise nil
    allow(Rails.cache).to receive(:fetch) do |key, options|
      if key == Ccra::BaseService::REDIS_TOKEN_KEY
        access_token
      else
        nil
      end
    end

    Settings.vaos ||= OpenStruct.new
    Settings.vaos.ccra ||= OpenStruct.new
    Settings.vaos.ccra.tap do |ccra|
      ccra.api_url = 'http://ccra.api.example.com'
      ccra.base_path = 'csp/healthshare/ccraint/rest'
      ccra.key_path = '/path/to/key.pem'
      ccra.client_id = 'test_client'
      ccra.kid = 'test_kid'
      ccra.audience_claim_url = 'https://test.example.com'
      ccra.access_token_url = 'https://test.example.com/token'
      ccra.grant_type = 'client_credentials'
      ccra.scopes = 'test.scope'
      ccra.client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
    end
  end

  describe '#get_vaos_referral_list' do
    let(:icn) { '1012845331V153043' }
    let(:referral_status) { "'S','BP','AP','AC','A','I'" }

    context 'with successful response', :vcr do
      it 'returns an array of ReferralListEntry objects' do
        VCR.use_cassette('vaos/ccra/post_referral_list_success') do
          result = subject.get_vaos_referral_list(icn, referral_status)
          expect(result).to be_an(Array)
          expect(result.size).to eq(3)
          expect(result.first).to be_a(Ccra::ReferralListEntry)
          expect(result.first.referral_id).to eq('5682')
          expect(result.first.type_of_care).to eq('CARDIOLOGY')
        end
      end
    end

    context 'with empty response', :vcr do
      let(:referral_status) { 'INVALID' }

      it 'returns an empty array' do
        VCR.use_cassette('vaos/ccra/post_referral_list_empty') do
          result = subject.get_vaos_referral_list(icn, referral_status)
          expect(result).to be_an(Array)
          expect(result).to be_empty
        end
      end
    end

    context 'with error response', :vcr do
      let(:icn) { 'invalid' }

      it 'raises a BackendServiceException' do
        VCR.use_cassette('vaos/ccra/post_referral_list_error') do
          expect { subject.get_vaos_referral_list(icn, referral_status) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end

  describe '#get_referral' do
    let(:id) { '984_646372' }
    let(:mode) { '2' }

    context 'with successful response', :vcr do
      it 'returns a ReferralDetail object' do
        VCR.use_cassette('vaos/ccra/post_get_referral_success') do
          result = subject.get_referral(id, mode)
          expect(result).to be_a(Ccra::ReferralDetail)
          expect(result.type_of_care).to eq('CARDIOLOGY')
          expect(result.referral_number).to eq('VA0000005681')
        end
      end
    end

    context 'when referral not found', :vcr do
      let(:id) { 'invalid_id' }

      it 'raises not found error' do
        VCR.use_cassette('vaos/ccra/post_get_referral_not_found') do
          expect { subject.get_referral(id, mode) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    context 'with error response', :vcr do
      let(:id) { 'error_id' }

      it 'raises a BackendServiceException' do
        VCR.use_cassette('vaos/ccra/post_get_referral_error') do
          expect { subject.get_referral(id, mode) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end
end
