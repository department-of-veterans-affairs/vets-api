# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rails_helper'

RSpec.describe 'Evidence Waiver 5103', type: :request,
                                       openapi_spec: Rswag::TextHelpers.new.claims_api_docs, production: false do
  let(:veteran_id) { '1012667145V762142' }
  let(:sponsor_id) { '1012861229V078999' }
  let(:claim_id) { '600131328' }
  let(:sub_path) { "/services/claims/v2/veterans/#{veteran_id}/claims/#{claim_id}/5103" }
  let(:error_sub_path) { "/services/claims/v2/veterans/#{veteran_id}/claims/abc123/5103" }
  let(:scopes) { %w[claim.write claim.read] }
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
                  VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                    allow_any_instance_of(ClaimsApi::MiscellaneousBGSOperations)
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
                VCR.use_cassette('claims_api/bgs/benefit_claim/find_bnft_claim_400') do
                  allow_any_instance_of(ClaimsApi::MiscellaneousBGSOperations)
                    .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })

                  post error_sub_path, headers: auth_header

                  expect(response.status).to eq(404)
                end
              end
            end
          end

          context 'when sponsorICN is provided' do
            it 'passes for a valid type' do
              bgs_claim_response = build(:bgs_response_with_one_lc_status).to_h
              bgs_claim_response[:benefit_claim_details_dto][:bnft_claim_type_cd] = '140ISCD'
              expect_any_instance_of(ClaimsApi::MiscellaneousBGSOperations)
                .to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(bgs_claim_response)

              mock_ccg(scopes) do |auth_header|
                allow_any_instance_of(ClaimsApi::MiscellaneousBGSOperations)
                  .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })

                post sub_path, params: { sponsorIcn: sponsor_id }, headers: auth_header

                expect(response.status).to eq(200)
              end
            end

            it 'silently passes for an invalid type' do
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                  allow_any_instance_of(ClaimsApi::MiscellaneousBGSOperations)
                    .to receive(:find_by_ssn).and_return({ file_nbr: '123456780' })
                  post sub_path, params: { sponsorIcn: sponsor_id }, headers: auth_header

                  expect(response.status).to eq(200)
                end
              end
            end
          end

          context 'when a veteran does not have a file number' do
            it 'returns an error message' do
              mock_ccg(scopes) do |auth_header|
                VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                  allow_any_instance_of(ClaimsApi::V2::Veterans::EvidenceWaiverController)
                    .to receive(:file_number_check).and_return(@file_number = nil)

                  post sub_path, headers: auth_header
                  json = JSON.parse(response.body)
                  expect_res = json['errors'][0]['detail']

                  expect(expect_res).to eq(
                    "Unable to locate Veteran's File Number. " \
                    'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.'
                  )
                end
              end
            end
          end

          context 'scopes' do
            let(:invalid_scopes) { %w[system/526-pdf.override] }
            let(:ews_scopes) { %w[system/claim.write] }

            context 'evidence waiver' do
              it 'returns a 200 response when successful' do
                mock_ccg_for_fine_grained_scope(ews_scopes) do |auth_header|
                  VCR.use_cassette('claims_api/bgs/benefit_claim/update_5103_200') do
                    post sub_path, headers: auth_header
                    expect(response).to have_http_status(:ok)
                  end
                end
              end

              it 'returns a 401 unauthorized with incorrect scopes' do
                mock_ccg_for_fine_grained_scope(invalid_scopes) do |auth_header|
                  post sub_path, headers: auth_header
                  expect(response).to have_http_status(:unauthorized)
                end
              end
            end
          end
        end
      end
    end
  end
end
