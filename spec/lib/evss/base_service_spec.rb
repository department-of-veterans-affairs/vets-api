# frozen_string_literal: true
require 'rails_helper'
require_dependency 'evss/claims_service'

describe EVSS::BaseService do
  context 'with an outage' do
    let(:service) { EVSS::ClaimsService.new({}) }

    before do
      EVSS::ClaimsService.breakers_service.begin_forced_outage!
    end

    it 'raises an error on get' do
      expect { service.send(:get, 'vbaClaimStatusService/getClaims') }.to raise_exception(Breakers::OutageException)
    end

    it 'raises an error on post' do
      expect do
        service.send(:post, 'claimServicesExternalService/listAllIntentToFile')
      end.to raise_exception(Breakers::OutageException)
    end
  end
end
