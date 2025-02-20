# frozen_string_literal: true

require 'rails_helper'
require 'evss/pciu_address/response_strategy'

describe EVSS::PCIUAddress::ResponseStrategy do
  let(:user) { build(:user, :loa3) }
  let(:service) { EVSS::PCIUAddress::Service.new(user) }
  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:countries_response) { EVSS::PCIUAddress::CountriesResponse.new(200, faraday_response) }

  before do
    allow(faraday_response).to receive_messages(status: 200, body: { cnp_countries: %w[Afghanistan Albania Algeria] })
  end

  describe '#cache_or_service' do
    context 'when the cache is empty' do
      it 'caches and return the response' do
        allow(service).to receive(:get_countries).and_return(countries_response)
        expect(subject.redis_namespace).to receive(:set).once
        response = subject.cache_or_service(:countries) { service.get_countries }
        expect(response).to be_ok
      end
    end

    context 'when there is cached data' do
      it 'does not hit service and returns the cached data' do
        subject.cache(:countries, countries_response)
        expect(service).not_to receive(:get_countries)
        response = subject.cache_or_service(:countries) { service.get_countries }
        expect(response).to be_ok
      end
    end
  end
end
