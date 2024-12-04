# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'fake_vbms.rb')

RSpec.describe 'Mobile::V0::Claims::DecisionLetters', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '24811694708759028') }

  before do
    allow(VBMS::Client).to receive(:from_env_vars).and_return(FakeVBMS.new)
    allow(Flipper).to receive(:enabled?).with(:mobile_claims_log_decision_letter_sent, nil).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:mobile_filter_doc_27_decision_letters_out).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:cst_include_ddl_5103_letters, nil).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:cst_include_ddl_sqd_letters, nil).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:cst_include_ddl_boa_letters, nil).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:mobile_claims_log_decision_letter_sent).and_return(false)
  end

  # This endpoint's upstream service mocks it's own data for test env. HTTP client is not exposed by the
  # connect_vbms gem so it cannot intercept the actual HTTP request, making the use of VCRs not possible.
  # This means we cannot test error states for the index endpoint within specs
  describe 'GET /mobile/v0/decision-letters' do
    context 'when user does not have access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns forbidden' do
        get '/mobile/v0/claims/decision-letters', headers: sis_headers
        assert_schema_conform(403)
      end
    end

    context 'with a valid response' do
      context 'with mobile_filter_doc_27_decision_letters_out flag enabled' do
        it 'returns expected decision letters' do
          allow(Flipper).to receive(:enabled?).with(:mobile_filter_doc_27_decision_letters_out).and_return(true)
          get '/mobile/v0/claims/decision-letters', headers: sis_headers
          assert_schema_conform(200)
          decision_letters = response.parsed_body['data']
          first_received_at = decision_letters.first.dig('attributes', 'receivedAt')
          last_received_at = decision_letters.last.dig('attributes', 'receivedAt')
          expect(decision_letters.count).to eq(5)
          expect(first_received_at).to be >= last_received_at
          expect(response.body).to match_json_schema('decision_letter')
          doc_types = decision_letters.map { |letter| letter.dig('attributes', 'docType') }.uniq
          expect(doc_types).to eq(%w[184])
        end
      end

      context 'with mobile_filter_doc_27_decision_letters_out flag disabled' do
        it 'returns expected decision letters' do
          allow(Flipper).to receive(:enabled?).with(:mobile_filter_doc_27_decision_letters_out).and_return(false)

          get '/mobile/v0/claims/decision-letters', headers: sis_headers
          assert_schema_conform(200)
          decision_letters = response.parsed_body['data']
          first_received_at = decision_letters.first.dig('attributes', 'receivedAt')
          last_received_at = decision_letters.last.dig('attributes', 'receivedAt')
          expect(decision_letters.count).to eq(6)
          expect(first_received_at).to be >= last_received_at
          expect(response.body).to match_json_schema('decision_letter')
          doc_types = decision_letters.map { |letter| letter.dig('attributes', 'docType') }.uniq
          expect(doc_types).to eq(%w[27 184])
        end
      end
    end
  end

  describe 'GET /mobile/v0/decision-letters/:document_id/download' do
    it 'retrieves a single letter based on document id' do
      doc_id = '{27832B64-2D88-4DEE-9F6F-DF80E4CAAA87}'

      VCR.use_cassette('mobile/bgs/uploaded_document_service/uploaded_document_data') do
        VCR.use_cassette('mobile/bgs/people_service/person_data') do
          get "/mobile/v0/claims/decision-letters/#{CGI.escape(doc_id)}/download", headers: sis_headers
          assert_schema_conform(200)
        end
      end
    end

    it 'raises a RecordNotFound exception when it cannot find a document' do
      doc_id = '{37832B64-2D88-4DEE-9F6F-DF80E4CAAA87}'

      VCR.use_cassette('mobile/bgs/uploaded_document_service/uploaded_document_data') do
        VCR.use_cassette('mobile/bgs/people_service/person_data') do
          get "/mobile/v0/claims/decision-letters/#{CGI.escape(doc_id)}/download", headers: sis_headers
          assert_schema_conform(404)
        end
      end
    end
  end
end
