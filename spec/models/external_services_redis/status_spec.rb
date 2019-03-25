# frozen_string_literal: true

require 'rails_helper'

describe ExternalServicesRedis::Status do
  let(:external_services) { ExternalServicesRedis::Status.new }
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

  it 'sets its cache to expire (ttl) after 60 seconds' do
    expect(ExternalServicesRedis::Status.redis_namespace_ttl).to eq 60
  end

  describe '#fetch_or_cache' do
    let(:fetch_or_cache) { external_services.fetch_or_cache }

    it 'is an instance of PagerDuty::ExternalServices::Response' do
      expect(fetch_or_cache.class).to eq PagerDuty::ExternalServices::Response
    end

    it "includes the HTTP status code from call to PagerDuty's API" do
      expect(fetch_or_cache.status).to eq 200
    end

    it "includes the time from the call to PagerDuty's API" do
      expect(fetch_or_cache.reported_at).to be_present
    end

    it 'includes an array of PagerDuty::Models::Service hashes', :aggregate_failures do
      expect(fetch_or_cache.statuses.class).to eq Array

      fetch_or_cache.statuses.each do |status|
        expect(status.class).to eq Hash
      end
    end

    it 'includes the relevant status details about each external service', :aggregate_failures do
      service_status = fetch_or_cache.statuses.first

      expect(service_status[:service]).to be_present
      expect(service_status[:status]).to be_present
      expect(service_status[:last_incident_timestamp]).to be_present
    end

    context 'when the cache is empty' do
      it 'should cache and return the response', :aggregate_failures do
        expect(external_services).to receive(:cache).once
        expect_any_instance_of(PagerDuty::ExternalServices::Service).to receive(:get_services).once
        expect(external_services.fetch_or_cache.class).to eq PagerDuty::ExternalServices::Response
      end
    end
  end

  describe '#response_status' do
    it "returns the HTTP status code from call to PagerDuty's API" do
      expect(external_services.response_status).to eq 200
    end
  end

  describe '#reported_at' do
    it "returns the time from the call to PagerDuty's API", :aggregate_failures do
      expect(external_services.reported_at).to be_present
      expect(external_services.reported_at.class).to eq Time
    end
  end
end
