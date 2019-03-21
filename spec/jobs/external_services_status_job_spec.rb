# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalServicesStatusJob do
  describe '#perform' do
    let(:get_services_response) do
      VCR.use_cassette('pagerduty/external_services/get_services', VCR::MATCH_EVERYTHING) do
        PagerDuty::ExternalServices::Service.new.get_services
      end
    end

    before do
      allow_any_instance_of(
        PagerDuty::ExternalServices::Service
      ).to receive(:get_services).and_return(get_services_response)

      allow_any_instance_of(ExternalServicesRedis::Status).to receive(:cache).and_return(true)
    end

    it 'calls ExternalServicesRedis::Status.new.fetch_or_cache' do
      expect_any_instance_of(ExternalServicesRedis::Status).to receive(:fetch_or_cache)

      described_class.new.perform
    end

    it 'calls PagerDuty::ExternalServices::Service.new.get_services' do
      expect_any_instance_of(PagerDuty::ExternalServices::Service).to receive(:get_services)

      described_class.new.perform
    end
  end
end
