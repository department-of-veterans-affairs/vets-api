# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralService do
  subject { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234', flipper_id: '1234', icn: '1012845331V153043') }
  let(:session_token) { 'fake-session-token' }
  let(:request_id) { 'request-id' }

  before do
    allow(RequestStore.store).to receive(:[]).with('request_id').and_return(request_id)

    # Mock the session token from UserService
    allow_any_instance_of(VAOS::UserService).to receive(:session).with(user).and_return(session_token)

    Settings.vaos ||= OpenStruct.new
    Settings.vaos.ccra ||= OpenStruct.new
    Settings.vaos.ccra.tap do |ccra|
      ccra.api_url = 'http://ccra.api.example.com'
      ccra.base_path = 'vaos/v1/patients'
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
          expect(result.first.referral_number).to eq('VA0000005681')
          expect(result.first.category_of_care).to eq('CARDIOLOGY')
          expect(result.first.referral_consult_id).to eq('984_646372')
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
    let(:icn) { '1012845331V153043' }

    context 'with successful response', :vcr do
      it 'returns a ReferralDetail object' do
        VCR.use_cassette('vaos/ccra/post_get_referral_success') do
          result = subject.get_referral(id, icn)
          expect(result).to be_a(Ccra::ReferralDetail)
          expect(result.category_of_care).to eq('CARDIOLOGY')
          expect(result.referral_number).to eq('VA0000005681')
        end
      end
    end

    context 'when referral not found', :vcr do
      let(:id) { 'invalid_id' }

      it 'raises not found error' do
        VCR.use_cassette('vaos/ccra/post_get_referral_not_found') do
          expect { subject.get_referral(id, icn) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    context 'with error response', :vcr do
      let(:id) { 'error_id' }

      it 'raises a BackendServiceException' do
        VCR.use_cassette('vaos/ccra/post_get_referral_error') do
          expect { subject.get_referral(id, icn) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end
end
