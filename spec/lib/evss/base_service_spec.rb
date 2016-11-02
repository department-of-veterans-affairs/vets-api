# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'

# :nocov:
# TODO: (AJM) Add these back when breakers is turned back on
describe EVSS::BaseService do
  context 'with an outage' do
    let(:service) { EVSS::ClaimsService.new({}) }

    before do
      EVSS::ClaimsService.breakers_service.begin_forced_outage!
    end

    xit 'raises an error on get' do
      expect { service.all_claims }.to raise_exception(Breakers::OutageException)
    end

    xit 'raises an error on post' do
      expect { service.find_claim_by_id(123) }.to raise_exception(Breakers::OutageException)
    end
  end
end
# :nocov:
