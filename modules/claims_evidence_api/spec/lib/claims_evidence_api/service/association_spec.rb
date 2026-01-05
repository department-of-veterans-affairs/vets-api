# frozen_string_literal: true

require 'rails_helper'

require 'claims_evidence_api/service/association'

require_relative 'shared/service'

RSpec.describe ClaimsEvidenceApi::Service::Association do
  let(:service) { described_class.new }

  let(:uuid) { SecureRandom.hex }
  let(:claim_ids) { ['first', uuid, 3, SecureRandom.hex] }
  let(:associated) { claim_ids.map(&:to_s) }

  it_behaves_like 'a ClaimsEvidenceApi::Service class'

  describe '#retrieve' do
    it 'performs a GET' do
      path = "files/#{uuid}/associations/claims"
      expect(service).to receive(:perform).with(:get, path, {})
      service.retrieve(uuid)
    end
  end

  describe '#get' do
    it 'performs a GET via class method' do
      allow(ClaimsEvidenceApi::Service::Association).to receive(:new).and_return service

      path = "files/#{uuid}/associations/claims"
      expect(service).to receive(:perform).with(:get, path, {})
      ClaimsEvidenceApi::Service::Association.get(uuid)
    end
  end

  describe '#associate' do
    it 'performs a PUT' do
      path = "files/#{uuid}/associations/claims"
      expect(service).to receive(:perform).with(:put, path, { associatedClaimIds: associated })
      service.associate(uuid, claim_ids)
    end
  end

  describe '#put' do
    it 'performs a PUT via class method' do
      allow(ClaimsEvidenceApi::Service::Association).to receive(:new).and_return service

      path = "files/#{uuid}/associations/claims"
      expect(service).to receive(:perform).with(:put, path, { associatedClaimIds: associated })
      ClaimsEvidenceApi::Service::Association.put(uuid, claim_ids)
    end
  end
end
