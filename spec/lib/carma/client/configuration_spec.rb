# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/configuration'

RSpec.describe CARMA::Client::Configuration, type: :model do
  let(:subject) { CARMA::Client::Configuration.instance }
  let(:app_config_url) { Settings['salesforce-carma'].url }

  describe 'configuration' do
    it 'is decedent of Salesforce::Configuration' do
      expect(described_class.ancestors).to include(Salesforce::Configuration)
    end

    it 'sets SALESFORCE_INSTANCE_URL' do
      expect(described_class::SALESFORCE_INSTANCE_URL).to eq(app_config_url)
    end

    it 'sets #service_name' do
      expect(subject.service_name).to eq('CARMA')
    end

    it 'sets #base_url' do
      expect(subject.base_path).to eq("#{app_config_url}/services/oauth2/token")
    end

    describe '#mock_enabled?' do
      it 'equals the salesforce carma mock setting' do
        expect(subject.mock_enabled?).to eq(Settings['salesforce-carma'].mock)
      end
    end
  end
end
