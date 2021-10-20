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
end
