# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'

describe EVSS::BaseService do
  context 'with a backend service error' do
    it 'should raise a faraday client error on a 500 class error', run_at: 'Wed, 13 Dec 2017 23:45:40 GMT' do
      VCR.use_cassette('evss/claims/error_504') do
        expect { claims_service.find_claim_by_id(1) }.to raise_exception(Faraday::ClientError)
      end
    end
  end

  context 'with an outage' do
    let(:service) { EVSS::ClaimsService.new({}) }

    before do
      EVSS::ClaimsService.breakers_service.begin_forced_outage!
    end

    it 'raises an error on get' do
      expect { service.all_claims }.to raise_exception(Breakers::OutageException)
    end

    it 'raises an error on post' do
      expect { service.find_claim_by_id(123) }.to raise_exception(Breakers::OutageException)
    end
  end
end
