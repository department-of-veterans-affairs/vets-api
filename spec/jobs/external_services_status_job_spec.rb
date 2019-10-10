# frozen_string_literal: true

require 'rails_helper'
require 'support/pagerduty/services/spec_setup'

RSpec.describe ExternalServicesStatusJob do
  include_context 'simulating Redis caching of PagerDuty#get_services'

  describe '#perform' do
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
