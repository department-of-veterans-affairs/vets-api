# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe Ccra::ReferralService do
  subject { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234') }

  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'X-Request-ID' => 'request-id'
    }
  end

  before do
    allow(RequestStore.store).to receive(:[]).with('request_id').and_return('request-id')
    Settings.vaos ||= OpenStruct.new
    Settings.vaos.ccra ||= OpenStruct.new
    Settings.vaos.ccra.tap do |ccra|
      ccra.api_url = 'http://test.example.com'
      ccra.base_path = 'api/v1'
    end

    stub_const('ReferralListEntry', Class.new do
      def initialize(attrs)
        @attrs = attrs
      end

      def self.build_collection(data)
        Array(data).map { |item| new(item) }
      end

      def referral_id
        @attrs['referralId']
      end

      def status
        @attrs['status']
      end

      def service_type
        @attrs['serviceType']
      end
    end)

    stub_const('ReferralDetail', Class.new do
      def initialize(attrs)
        @attrs = attrs['Referral']
      end

      def category_of_care
        @attrs['CategoryOfCare']
      end

      def referral_number
        @attrs['ReferralNumber']
      end

      def status
        @attrs['Status']
      end
    end)
  end

  describe '#get_vaos_referral_list' do
    let(:icn) { '123456789' }
    let(:referral_status) { 'ACTIVE' }
    let(:response_body) do
      [
        {
          'referralId' => '123',
          'status' => 'ACTIVE',
          'serviceType' => 'CARDIOLOGY'
        }
      ]
    end

    context 'with successful response' do
      before do
        allow(subject).to receive(:perform)
          .with(:post, '/api/v1/VAOS/patients/ReferralList',
                { ICN: icn, ReferralStatus: referral_status }, headers)
          .and_return(double('Response', body: response_body))
      end

      it 'returns an array of ReferralListEntry objects' do
        result = subject.get_vaos_referral_list(icn, referral_status)
        expect(result).to be_an(Array)
        expect(result.first).to be_a(ReferralListEntry)
        expect(result.first.referral_id).to eq('123')
        expect(result.first.status).to eq('ACTIVE')
        expect(result.first.service_type).to eq('CARDIOLOGY')
      end
    end

    context 'with error response' do
      before do
        allow(subject).to receive(:perform)
          .and_raise(Common::Exceptions::BackendServiceException.new('CCRA_502', { status: 502 }, 502))
      end

      it 'raises a BackendServiceException' do
        expect { subject.get_vaos_referral_list(icn, referral_status) }
          .to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end

  describe '#get_referral' do
    let(:id) { '123456' }
    let(:mode) { '2' }
    let(:response_body) do
      {
        'Referral' => {
          'CategoryOfCare' => 'CARDIOLOGY',
          'ReferralNumber' => 'VA0000005681',
          'Status' => 'First Appointment Made'
        }
      }
    end

    context 'with successful response' do
      before do
        allow(subject).to receive(:perform)
          .with(:post, '/api/v1/ReferralUtil/GetReferral',
                { Id: id, Mode: mode }, headers)
          .and_return(double('Response', body: response_body))
      end

      it 'returns a ReferralDetail object' do
        result = subject.get_referral(id, mode)
        expect(result).to be_a(ReferralDetail)
        expect(result.category_of_care).to eq('CARDIOLOGY')
        expect(result.referral_number).to eq('VA0000005681')
        expect(result.status).to eq('First Appointment Made')
      end
    end

    context 'with error response' do
      before do
        allow(subject).to receive(:perform)
          .and_raise(Common::Exceptions::BackendServiceException.new('CCRA_502', { status: 502 }, 502))
      end

      it 'raises a BackendServiceException' do
        expect { subject.get_referral(id, mode) }
          .to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end
end
