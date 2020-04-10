# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CARMA::Client::Configuration, type: :model do
  let(:app_config_url) { Settings['salesforce-carma'].url }

  describe 'configuration' do
    it 'is decedent of Salesforce::Configuration' do
      expect(described_class.ancestors).to include(Salesforce::Configuration)
    end

    it 'sets SALESFORCE_INSTANCE_URL' do
      expect(described_class::SALESFORCE_INSTANCE_URL).to eq(app_config_url)
    end
  end
end
