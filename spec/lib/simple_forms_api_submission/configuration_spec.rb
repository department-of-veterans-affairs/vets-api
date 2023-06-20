# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api_submission/configuration'

describe SimpleFormsApiSubmission::Configuration do
  describe '#base_path' do
    it 'has an base path' do
      expect(SimpleFormsApiSubmission::Configuration.instance.base_path).to eq(Settings.forms_api_benefits_intake.url)
    end
  end

  describe '#service_name' do
    it 'has a service name' do
      expect(SimpleFormsApiSubmission::Configuration.instance.service_name).to eq('SimpleFormsApiSubmission')
    end
  end

  describe '.read_timeout' do
    it 'uses the setting' do
      expect(SimpleFormsApiSubmission::Configuration.instance.read_timeout).to eq(20)
    end
  end
end
