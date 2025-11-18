# frozen_string_literal: true

require 'rails_helper'

require 'claims_evidence_api/service/documenttypes'

require_relative 'shared/service'

RSpec.describe ClaimsEvidenceApi::Service::DocumentTypes do
  let(:service) { described_class.new }

  it_behaves_like 'a ClaimsEvidenceApi::Service class'

  describe '#retrieve' do
    it 'performs a GET' do
      path = 'documenttypes'
      expect(service).to receive(:perform).with(:get, path, {})
      service.retrieve
    end
  end

  describe '#get' do
    it 'performs a GET via class method' do
      allow(ClaimsEvidenceApi::Service::DocumentTypes).to receive(:new).and_return service

      path = 'documenttypes'
      expect(service).to receive(:perform).with(:get, path, {})
      ClaimsEvidenceApi::Service::DocumentTypes.get
    end
  end
end
