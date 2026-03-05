# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::CaseGetDocument::Service do
  let(:icn) { '1012662125V786396' }
  let(:service) { described_class.new(icn) }

  describe '#get_document' do
    let(:raw_env) { instance_double(Faraday::Env, status: 200) }
    let(:url) { "#{Settings.res.base_url}/suite/webapi/get-case-get-document" }
    let(:headers) { { 'Appian-API-Key' => Settings.res.api_key, 'Accept' => 'application/pdf' } }
    let(:params) { { res_case_id: 4574, document_type: '626' } }
    let(:expected_body) { { icn:, resCaseId: 4574, documentType: '626' }.to_json }
    let(:request_params) { [:post, url, expected_body, headers] }

    it 'sends payload to RES and returns env' do
      allow(service).to receive(:perform).with(*request_params).and_return(raw_env)
      expect(service.get_document(params)).to eq(raw_env)
      expect(service).to have_received(:perform).with(*request_params)
    end
  end
end
