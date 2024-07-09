# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::BD do
  subject { described_class.new }

  before do
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
  end

  describe '#upload' do
    let(:claim) { create(:auto_established_claim, evss_id: 600_400_688) }
    let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-526EZ.pdf' }

    it 'uploads a document to BD' do
      VCR.use_cassette('claims_api/bd/upload') do
        result = subject.upload(claim:, pdf_path:)
        expect(result).to be_a Hash
        expect(result[:data][:success]).to be true
      end
    end

    it 'uploads an attachment to BD' do
      result = subject.send(:generate_upload_body, claim:, doc_type: 'L023', original_filename: '21-526EZ.pdf',
                                                   pdf_path:)
      js = JSON.parse(result[:parameters].read)
      expect(js['data']['docType']).to eq 'L023'
    end

    context 'when the upstream service is down' do
      let(:client) { instance_double(Faraday::Connection) }
      let(:response) { instance_double(Faraday::Response, body: 'failed to request: timeout') }

      before do
        allow(Faraday).to receive(:new).and_return(client)
        allow(client).to receive(:post).and_return(response)
      end

      it 'raises a GatewayTimeout exception' do
        expect { subject.upload(claim:, pdf_path:) }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end
  end

  describe '#search', vcr: 'claims_api/v2/claims_show' do
    let(:claim_id) { '600397218' }
    let(:file_number) { '796378782' }

    it 'locates claim documents when provided a fileNumber and claimId' do
      result = subject.search(claim_id, file_number)

      expect(result).to be_a Hash
      expect(result[:data][:documents]).to be_truthy
    end

    context 'when the upstream service is down' do
      let(:client) { instance_double(Faraday::Connection) }
      let(:response) { instance_double(Faraday::Response, body: 'failed to request: timeout') }

      before do
        allow(Rails).to receive(:logger).and_return(double('Logger', info: true))
        allow(Faraday).to receive(:new).and_return(client)
        allow(client).to receive(:post).and_return(response)
      end

      it 'logs the error and returns an empty hash' do
        result = subject.search(claim_id, file_number)
        expect(Rails.logger).to have_received(:info)
          .with(%r{benefits_documents :: {"detail":"/search failure for claimId #{claim_id}, Gateway timeout"}})
        expect(result).to eq({})
      end
    end
  end
end
