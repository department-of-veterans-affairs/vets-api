# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'
require 'vetext/service'

describe 'VEText::Service' do
  let(:service) { VEText::Service.new }

  describe '#register' do
    context 'with a new device token' do
      let(:response) do
        VCR.use_cassette('vetext/register_success') do
          service.register(
              'app-sid',
              'device-token',
              'icn',
              'ios',
              '13.1'
          )
        end
      end

      it 'returns the unique sid for the app/device/icn' do
        expect(response).to include(sid: '8E7F6585AAB1F6CF2E16058183303383')
      end
    end

    context 'when a 400 is returned' do
        it 'raises an error' do
          VCR.use_cassette('vetext/register_bad_request') do
            expect {
                service.register(
                    'app-sid',
                    'device-token',
                    'icn',
                    'ios',
                    '13.1'
                )
            }.to raise_error(Common::Exceptions::BackendServiceException, /VETEXT_400/)
          end
        end
      end
    end

    context 'when a 500 is returned' do
      it 'raises an error' do
          VCR.use_cassette('vetext/register_internal_server_error') do
          expect {
              service.register(
                  'app-sid',
                  'device-token',
                  'icn',
                  'ios',
                  '13.1'
              )
          }.to raise_error(Common::Exceptions::BackendServiceException, /VETEXT_502/)
          end
      end
    end

end
