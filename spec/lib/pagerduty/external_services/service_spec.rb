# frozen_string_literal: true

require 'rails_helper'
require 'pagerduty/external_services/service'

describe PagerDuty::ExternalServices::Service do
  let(:subject) { described_class.new }

  describe '#get_services' do
    let(:response) do
      VCR.use_cassette('pagerduty/external_services/get_services', VCR::MATCH_EVERYTHING) do
        subject.get_services
      end
    end

    it 'returns a status of 200' do
      expect(response).to be_ok
    end

    it 'sets the #reported_at value' do
      expect(response.reported_at).to be_present
    end

    it 'returns an array of PagerDuty::Models::Service hashes', :aggregate_failures do
      expect(response.statuses).to be_a(Array)
      expect(response.statuses.first).to be_a(Hash)
    end

    context 'when PagerDuty returns an unknown service status' do
      it 'raises an exception', :aggregate_failures do
        VCR.use_cassette('pagerduty/external_services/get_services_invalid_status', VCR::MATCH_EVERYTHING) do
          expect { subject.get_services }.to raise_error do |e|
            expect(e.class).to eq Common::Exceptions::ValidationErrors
            expect(e.status_code).to eq 422
            expect(e.message).to include 'Validation error'
          end
        end
      end
    end

    context 'when the PagerDuty API rate limit has been exceeded' do
      it 'raises an exception', :aggregate_failures do
        VCR.use_cassette('pagerduty/external_services/get_services_429', VCR::MATCH_EVERYTHING) do
          expect { subject.get_services }.to raise_error do |e|
            expect(e.class).to eq PagerDuty::ServiceException
            expect(e.status_code).to eq 429
            expect(e.message).to include 'PAGERDUTY_429'
          end
        end
      end
    end
  end
end
