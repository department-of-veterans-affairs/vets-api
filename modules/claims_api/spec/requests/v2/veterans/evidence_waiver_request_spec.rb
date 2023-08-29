# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'
require 'token_validation/v2/client'

RSpec.describe 'Evidence Waiver 5103', type: :request,
                                       swagger_doc: Rswag::TextHelpers.new.claims_api_docs, production: false do
  let(:veteran_id) { '1012667145V762142' }
  let(:claim_id) { '600131328' }
  let(:sub_path) { "/services/claims/v2/veterans/#{veteran_id}/claims/#{claim_id}/5103" }
  let(:error_sub_path) { "/services/claims/v2/veterans/#{veteran_id}/claims/abc123/5103" }
  let(:scopes) { %w[system/claim.read] }
  let(:ews) { build(:claims_api_evidence_waiver_submission) }
  let(:payload) do
    { 'ver' => 1,
      'cid' => '0oa8r55rjdDAH5Vaj2p7',
      'scp' => ['system/claim.write', 'system/claim.read'],
      'sub' => '0oa8r55rjdDAH5Vaj2p7' }
  end

  describe '5103 Waiver' do
    describe 'submit' do
      context 'Vet flow' do
        context 'when provided' do
          context 'when valid' do
            context 'when success' do
              it 'returns a 200' do
                mock_ccg(scopes) do |auth_header|
                  VCR.use_cassette('bgs/benefit_claim/update_5103_200') do
                    allow_any_instance_of(BGS::PersonWebService)
                      .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })

                    post sub_path, headers: auth_header

                    expect(response.status).to eq(200)
                  end
                end
              end
            end
          end

          context 'when not valid' do
            it 'returns a 401' do
              post sub_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(401)
            end
          end

          context 'when claim id is not found' do
            it 'returns a 404' do
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('bgs/benefit_claim/find_bnft_claim_400') do
                  allow_any_instance_of(BGS::PersonWebService)
                    .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })

                  post error_sub_path, headers: auth_header

                  expect(response.status).to eq(404)
                end
              end
            end
          end
        end
      end
    end
  end
end
