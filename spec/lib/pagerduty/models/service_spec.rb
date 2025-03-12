# frozen_string_literal: true

require 'rails_helper'
require 'support/pagerduty/services/valid'
require 'support/pagerduty/services/invalid'
require 'pagerduty/models/service'

describe PagerDuty::Models::Service do
  let(:pagerduty_service) { build(:pagerduty_service) }

  describe 'validations' do
    it 'has a valid factory' do
      expect(pagerduty_service).to be_valid
    end

    it 'validates for the :status to be one of the PagerDuty::Models::Service::STATUSES' do
      invalid_service = build(:pagerduty_service, status: 'some status')

      expect(invalid_service).not_to be_valid
    end
  end

  describe '.statuses_for' do
    let(:statuses) { described_class.statuses_for(valid_service) }
    let(:external_service) { statuses.first }

    it 'returns an array of Service objects', :aggregate_failures do
      expect(statuses.class).to eq Array
      expect(external_service.class).to eq PagerDuty::Models::Service
    end

    it 'strips "External:" from the name' do
      expect(external_service.service).to eq 'Appeals'
    end

    it 'sets the status to be one of the PagerDuty::Models::Service::STATUSES' do
      expect(PagerDuty::Models::Service::STATUSES).to include external_service.status
    end

    context 'with a Staging external service' do
      it 'removes the staging service from the returned list of services' do
        statuses = described_class.statuses_for(valid_staging_service)

        expect(statuses).to eq []
      end
    end

    context 'with an invalid service status' do
      it 'raises an error', :aggregate_failures do
        expect { described_class.statuses_for(invalid_status) }.to raise_error do |e|
          expect(e.class).to eq Common::Exceptions::ValidationErrors
          expect(e.errors.first.detail).to eq 'status - is not included in the list'
        end
      end
    end

    context 'with a missing service name' do
      it 'raises an error', :aggregate_failures do
        expect { described_class.statuses_for(nil_name) }.to raise_error do |e|
          expect(e.class).to eq Common::Exceptions::InvalidFieldValue
          expect(e.errors.first.detail).to include 'not a valid value'
        end
      end
    end

    context 'with an alternate service prefix' do
      before do
        allow(Settings.maintenance).to receive(:service_query_prefix).and_return('Staging: External: ')
      end

      it 'includes the staging service from the returned list of services' do
        statuses = described_class.statuses_for(valid_staging_service)
        expect(statuses.length).to eq 1
      end

      it 'strips the configured prefix from the name' do
        statuses = described_class.statuses_for(valid_staging_service)
        expect(statuses.first.service).to eq 'Appeals'
      end
    end
  end
end
