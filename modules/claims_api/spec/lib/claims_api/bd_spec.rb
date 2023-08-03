# frozen_string_literal: true

require 'rails_helper'
require 'bd/bd'

describe ClaimsApi::BD do
  subject { described_class.new }

  describe '#upload' do
    let(:claim) { create(:auto_established_claim, evss_id: 600_400_688) }
    let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-526EZ.pdf' }
    let(:file_number) { 796_130_115 }

    it 'uploads a document to BD' do
      VCR.use_cassette('bd/upload') do
        allow_any_instance_of(ClaimsApi::EVSSService::Token).to receive(:get_token).and_return('some-value-here')

        result = subject.upload(claim, pdf_path, file_number)
        expect(result).to be_a Hash
        expect(result[:data][:success]).to be true
      end
    end
  end
end
