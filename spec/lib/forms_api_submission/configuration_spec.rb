# frozen_string_literal: true

require 'rails_helper'
require 'forms_api_submission/configuration'

describe FormsApiSubmission::Configuration do
  describe '#base_path' do
    it 'has an base path' do
      expect(FormsApiSubmission::Configuration.instance.base_path).to eq(Settings.forms_api_benefits_intake.url)
    end
  end

  describe '#service_name' do
    it 'has a service name' do
      expect(FormsApiSubmission::Configuration.instance.service_name).to eq('FormsApiSubmission')
    end
  end

  describe '.read_timeout' do
    it 'uses the setting' do
      expect(FormsApiSubmission::Configuration.instance.read_timeout).to eq(20)
    end
  end
end
