# frozen_string_literal: true

require 'rails_helper'

require 'claims_evidence_api/service/period_of_service'

require_relative 'shared/service'

RSpec.describe ClaimsEvidenceApi::Service::PeriodOfService do
  let(:service) { described_class.new }
  let(:uuid) { SecureRandom.hex }

  it_behaves_like 'a ClaimsEvidenceApi::Service class'

  describe '#retrieve' do
    it 'performs a GET' do
      path = "files/#{uuid}/periodOfService"
      expect(service).to receive(:perform).with(:get, path, {})
      service.retrieve(uuid)
    end
  end

  describe '#get' do
    it 'performs a GET via class method' do
      allow(ClaimsEvidenceApi::Service::PeriodOfService).to receive(:new).and_return service

      path = "files/#{uuid}/periodOfService"
      expect(service).to receive(:perform).with(:get, path, {})
      ClaimsEvidenceApi::Service::PeriodOfService.get(uuid)
    end
  end
end
