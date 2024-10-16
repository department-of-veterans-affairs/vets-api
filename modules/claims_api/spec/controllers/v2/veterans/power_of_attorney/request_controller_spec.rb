# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../../rails_helper'

Rspec.describe ClaimsApi::V2::Veterans::PowerOfAttorney::RequestController, type: :request do
  include ClaimsApi::Engine.routes.url_helpers

  describe '#index' do
    let(:scopes) { %w[claim.read] }

    it 'raises a ParameterMissing error if poaCodes is not present' do
      expect do
        subject.index
      end.to raise_error(Common::Exceptions::ParameterMissing)
    end

    context 'when poaCodes is present but empty' do
      before do
        allow(subject).to receive(:form_attributes).and_return({ 'poaCodes' => [] })
      end

      it 'raises a ParameterMissing error' do
        expect do
          subject.index
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when poaCodes is present and valid' do
      let(:poa_codes) { %w[002 003 083] }

      it 'returns a list of claimants' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_valid') do
            post_request_with(poa_codes:, auth_header:)

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body).size).to eq(16)
          end
        end
      end
    end

    context 'when poaCodes is present but no records are found' do
      let(:poa_codes) { %w[XYZ] }

      it 'raises a ResourceNotFound error' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_not_found') do
            post_request_with(poa_codes:, auth_header:)

            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end
  end

  def post_request_with(poa_codes:, auth_header:)
    post v2_veterans_power_of_attorney_requests_path,
         params: { data: { attributes: { poaCodes: poa_codes } } }.to_json,
         headers: auth_header
  end
end
