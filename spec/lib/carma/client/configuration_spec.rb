# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CARMA::Client::Configuration, type: :model do
  describe 'configuration' do
    it 'sets SALESFORCE_INSTANCE_URL' do
      expect(described_class::SALESFORCE_INSTANCE_URL).to be(Settings['salesforce-carma'].url)
    end
  end

  describe '#service_name' do
    xit 'is set to CARMA' do
      # TODO: cannot call #new on Config object...
      expect(subject.service_name).to be('CARMA')
    end
  end
end
