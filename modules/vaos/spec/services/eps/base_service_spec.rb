# frozen_string_literal: true

require 'rails_helper'

describe Eps::BaseService do
  user_icn = '123456789V123456'

  let(:user) { double('User', account_uuid: '1234', icn: user_icn) }
  let(:service) { described_class.new(user) }
  let(:config) { instance_double(Eps::Configuration, api_url: 'https://api.wellhive.com', base_path: 'api/v1') }

  before do
    allow(service).to receive(:config).and_return(config)
  end

  describe '#patient_id' do
    it 'returns the user ICN' do
      expect(service.send(:patient_id)).to eq(user_icn)
    end

    it 'memoizes the ICN' do
      expect(user).to receive(:icn).once.and_return(user_icn)
      2.times { service.send(:patient_id) }
    end
  end

  describe '#check_for_eps_error!' do
    let(:response) { double('Response', status: 200) }

    before do
      allow(Rails.logger).to receive(:warn)
    end

    context 'when response data has no error field' do
      it 'does not raise exception for OpenStruct without error' do
        data = OpenStruct.new(id: '123', status: 'success')
        expect { service.send(:check_for_eps_error!, data, response) }.not_to raise_error
      end

      it 'does not raise exception for OpenStruct with blank error' do
        data = OpenStruct.new(id: '123', error: '')
        expect { service.send(:check_for_eps_error!, data, response) }.not_to raise_error
      end
    end

    context 'when response data has error field' do
      it 'raises exception for OpenStruct with error' do
        data = OpenStruct.new(id: '123', error: 'conflict')
        expect { service.send(:check_for_eps_error!, data, response) }
          .to raise_error(VAOS::Exceptions::BackendServiceException)
      end

      it 'logs the error without PII' do
        data = OpenStruct.new(id: '123', error: 'conflict')
        expect(Rails.logger).to receive(:warn).with(
          'EPS appointment error detected',
          hash_including(
            error_type: 'conflict',
            status: 200
          )
        )

        expect { service.send(:check_for_eps_error!, data, response) }
          .to raise_error(VAOS::Exceptions::BackendServiceException)
      end

      it 'uses provided method name in logging' do
        data = OpenStruct.new(error: 'conflict')
        expect(Rails.logger).to receive(:warn).with(
          'EPS appointment error detected',
          hash_including(
            error_type: 'conflict',
            method: 'test_method',
            status: 200
          )
        )

        expect { service.send(:check_for_eps_error!, data, response, 'test_method') }
          .to raise_error(VAOS::Exceptions::BackendServiceException)
      end

      it 'maps conflict errors to 409 status' do
        data = OpenStruct.new(error: 'conflict')

        begin
          service.send(:check_for_eps_error!, data, response)
        rescue VAOS::Exceptions::BackendServiceException => e
          expect(e.original_status).to eq(409)
        else
          raise 'Expected VAOS::Exceptions::BackendServiceException to be raised'
        end
      end

      it 'maps bad-request errors to 400 status' do
        data = OpenStruct.new(error: 'bad-request')

        begin
          service.send(:check_for_eps_error!, data, response)
        rescue VAOS::Exceptions::BackendServiceException => e
          expect(e.original_status).to eq(400)
        else
          raise 'Expected VAOS::Exceptions::BackendServiceException to be raised'
        end
      end

      it 'maps unknown errors to 422 status' do
        data = OpenStruct.new(error: 'unknown-error')

        begin
          service.send(:check_for_eps_error!, data, response)
        rescue VAOS::Exceptions::BackendServiceException => e
          expect(e.original_status).to eq(422)
        else
          raise 'Expected VAOS::Exceptions::BackendServiceException to be raised'
        end
      end
    end

    context 'when response data is other format' do
      it 'does not raise exception for other object types' do
        data = 'some string response'
        expect { service.send(:check_for_eps_error!, data, response) }.not_to raise_error
      end
    end
  end
end
