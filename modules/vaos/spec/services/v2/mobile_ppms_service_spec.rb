# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::MobilePPMSService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_provider' do
    context 'with a single provider id' do
      it 'returns a provider name' do
        VCR.use_cassette('vaos/v2/mobile_ppms_service/get_provider_200',
                         match_requests_on: %i[method path query], tag: :force_utf8) do
          response = subject.get_provider('1407938061')
          expect(response.name).to eq 'DEHGHAN, AMIR '
        end
      end
    end

    context 'when the upstream server returns a 400' do
      it 'raises a bad request' do
        VCR.use_cassette('vaos/v2/mobile_ppms_service/get_provider_400',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_provider(489) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/mobile_ppms_service/get_provider_500',
                         match_requests_on: %i[method path query]) do
          expect { subject.get_provider(489) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
