# frozen_string_literal: true

require 'rails_helper'
require 'common/client/configuration/base'

describe Common::Client::Configuration::Base do
  module SomeRandomModule
    class DerivedClass < Common::Client::Configuration::Base
      def base_path
        'https://fakehost.gov/base_path'
      end

      def service_name
        'derived_class'
      end
    end
  end

  subject { SomeRandomModule::DerivedClass.instance }

  describe '#service_exception' do
    it 'creates an exception class dynamically based on module name' do
      expect(SomeRandomModule).not_to be_const_defined('ServiceException')
      expect(subject.service_exception).to eq(SomeRandomModule::ServiceException)
      expect(SomeRandomModule).to be_const_defined('ServiceException')
    end
  end

  describe '#breakers_matcher' do
    let(:matcher) { subject.breakers_matcher }
    let(:breakers_service) { double('breakers_service', name: 'derived_class') }
    let(:request_env) do
      double('request_env',
             url: double('url',
                         host: 'fakehost.gov',
                         port: 443,
                         path: '/base_path/some/endpoint'))
    end

    context 'when request_service_name is provided' do
      it 'returns true when service names match' do
        result = matcher.call(breakers_service, request_env, 'derived_class')
        expect(result).to be true
      end

      it 'returns false when service names do not match' do
        result = matcher.call(breakers_service, request_env, 'HCA')
        expect(result).to be false
      end
    end

    context 'when request_service_name is not provided' do
      it 'returns true when URL matches host, port, and path prefix' do
        result = matcher.call(breakers_service, request_env, nil)
        expect(result).to be_truthy
      end

      it 'returns false when host does not match' do
        allow(request_env.url).to receive(:host).and_return('nope.gov')
        result = matcher.call(breakers_service, request_env, nil)
        expect(result).to be_falsey
      end

      it 'returns false when port does not match' do
        allow(request_env.url).to receive(:port).and_return(8080)
        result = matcher.call(breakers_service, request_env, nil)
        expect(result).to be_falsey
      end

      it 'returns false when path does not match prefix' do
        allow(request_env.url).to receive(:path).and_return('/different_path/endpoint')
        result = matcher.call(breakers_service, request_env, nil)
        expect(result).to be_falsey
      end
    end
  end
end
