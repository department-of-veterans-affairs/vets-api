# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'

describe EVSS::BaseService do
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
