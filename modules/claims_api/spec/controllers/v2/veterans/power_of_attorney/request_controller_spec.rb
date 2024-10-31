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
            index_request_with(poa_codes:, auth_header:)

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body).size).to eq(3)
          end
        end
      end
    end

    context 'when poaCodes is present but no records are found' do
      let(:poa_codes) { %w[XYZ] }

      it 'raises a ResourceNotFound error' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_not_found') do
            index_request_with(poa_codes:, auth_header:)

            expect(response).to have_http_status(:not_found)
          end
        end
      end
    end
  end

  describe '#decide' do
    let(:scopes) { %w[claim.write] }

    it 'raises a ParameterMissing error if procId is not present' do
      expect do
        subject.decide
      end.to raise_error(Common::Exceptions::ParameterMissing)
    end

    context 'when decision is not present' do
      before do
        allow(subject).to receive(:form_attributes).and_return({ 'procId' => '76529' })
      end

      it 'raises a ParameterMissing error if decision is not present' do
        expect do
          subject.decide
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when decision is not accepted or declined' do
      before do
        allow(subject).to receive(:form_attributes).and_return({ 'procId' => '76529', 'decision' => 'invalid' })
      end

      it 'raises a ParameterMissing error if decision is not accepted or declined' do
        expect do
          subject.decide
        end.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when procId is present and valid and decision is accepted' do
      let(:proc_id) { '76529' }
      let(:decision) { 'accepted' }

      it 'updates the secondaryStatus and returns a hash containing the ACC code' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
            decide_request_with(proc_id:, decision:, auth_header:)

            expect(response).to have_http_status(:ok)
            response_body = JSON.parse(response.body)
            expect(response_body['procId']).to eq(proc_id)
            expect(response_body['secondaryStatus']).to eq('ACC')
          end
        end
      end
    end

    context 'when procId is present but invalid' do
      let(:proc_id) { '1' }
      let(:decision) { 'accepted' }

      it 'raises an error' do
        mock_ccg(scopes) do |auth_header|
          VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_not_found') do
            decide_request_with(proc_id:, decision:, auth_header:)

            expect(response).to have_http_status(:internal_server_error)
          end
        end
      end
    end
  end

  def index_request_with(poa_codes:, auth_header:)
    post v2_veterans_power_of_attorney_requests_path,
         params: { data: { attributes: { poaCodes: poa_codes } } }.to_json,
         headers: auth_header
  end

  def decide_request_with(proc_id:, decision:, auth_header:)
    post v2_veterans_power_of_attorney_requests_decide_path,
         params: { data: { attributes: { procId: proc_id, decision: } } }.to_json,
         headers: auth_header
  end
end
