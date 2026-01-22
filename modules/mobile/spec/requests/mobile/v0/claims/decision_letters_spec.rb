# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

require 'claim_letters/providers/claim_letters/lighthouse_claim_letters_provider'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'fake_vbms.rb')

RSpec.describe 'Mobile::V0::Claims::DecisionLetters', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '24811694708759028') }

  before do
    allow(VBMS::Client).to receive(:from_env_vars).and_return(FakeVBMS.new)
    allow(Flipper).to receive(:enabled?).with(:mobile_claims_log_decision_letter_sent, anything).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:mobile_filter_doc_27_decision_letters_out).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:cst_include_ddl_5103_letters, anything).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:cst_include_ddl_sqd_letters, anything).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:cst_include_ddl_boa_letters, anything).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:mobile_claims_log_decision_letter_sent).and_return(false)
    allow(Flipper).to receive(:enabled?)
      .with(:cst_claim_letters_use_lighthouse_api_provider_mobile, anything)
      .and_return(false)
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

    context 'with cst_claim_letters_use_lighthouse_api_provider_mobile flag enabled' do
      let!(:response_body) do
        [{ 'document_id' => '12345678-ABCD-0123-cdef-124345679ABC',
           'series_id' => '12345678-ABCD-0123-cdef-124345679ABC',
           'version' => nil,
           'type_description' => 'VA 21-526 Veterans Application for Compensation or Pension',
           'type_id' => '184',
           'doc_type' => '184',
           'subject' => 'string',
           'received_at' => '2016-02-04',
           'source' => 'Lighthouse Benefits Documents claims-letters/search',
           'mime_type' => 'application/pdf',
           'alt_doc_types' => nil,
           'restricted' => false,
           'upload_date' => '2016-02-04' },
         { 'document_id' => '23456789-ABCD-0123-cdef-987654321ABC',
           'series_id' => '23456789-ABCD-0123-cdef-987654321ABC',
           'version' => nil,
           'type_description' => 'Board decision',
           'type_id' => '27',
           'doc_type' => '27',
           'subject' => 'string',
           'received_at' => '2015-02-04',
           'source' => 'Lighthouse Benefits Documents claims-letters/search',
           'mime_type' => 'application/pdf',
           'alt_doc_types' => nil,
           'restricted' => false,
           'upload_date' => '2015-02-04' }]
      end

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:cst_claim_letters_use_lighthouse_api_provider_mobile, anything)
          .and_return(true)

        lighthouse_claim_letters_provider_double = double
        allow(LighthouseClaimLettersProvider).to receive(:new).and_return(lighthouse_claim_letters_provider_double)
        allow(lighthouse_claim_letters_provider_double).to receive(:get_letters).and_return(response_body)
      end

      context 'with a valid response' do
        context 'with mobile_filter_doc_27_decision_letters_out flag enabled' do
          let!(:claim_letter_doc_response) do
            { 'data' => [{ 'id' => '12345678-ABCD-0123-cdef-124345679ABC', 'type' => 'decisionLetter',
                           'attributes' => {
                             'seriesId' => '12345678-ABCD-0123-cdef-124345679ABC',
                             'version' => nil,
                             'typeDescription' => 'VA 21-526 Veterans Application for Compensation or Pension',
                             'typeId' => '184',
                             'docType' => '184',
                             'subject' => 'string',
                             'receivedAt' => '2016-02-04',
                             'source' => 'Lighthouse Benefits Documents claims-letters/search',
                             'mimeType' => 'application/pdf',
                             'altDocTypes' => nil,
                             'restricted' => false,
                             'uploadDate' => '2016-02-04'
                           } }] }
          end

          before do
            allow(Flipper).to receive(:enabled?).with(:mobile_filter_doc_27_decision_letters_out).and_return(true)
          end

          it 'returns expected decision letters' do
            get '/mobile/v0/claims/decision-letters', headers: sis_headers
            assert_schema_conform(200)
            expect(response.body).to match_json_schema('decision_letter')
            expect(response.parsed_body).to eq(claim_letter_doc_response)
          end
        end

        context 'with mobile_filter_doc_27_decision_letters_out flag disabled' do
          let!(:claim_letter_doc_response) do
            { 'data' => [{ 'id' => '12345678-ABCD-0123-cdef-124345679ABC', 'type' => 'decisionLetter',
                           'attributes' => {
                             'seriesId' => '12345678-ABCD-0123-cdef-124345679ABC',
                             'version' => nil,
                             'typeDescription' => 'VA 21-526 Veterans Application for Compensation or Pension',
                             'typeId' => '184',
                             'docType' => '184',
                             'subject' => 'string',
                             'receivedAt' => '2016-02-04',
                             'source' => 'Lighthouse Benefits Documents claims-letters/search',
                             'mimeType' => 'application/pdf',
                             'altDocTypes' => nil,
                             'restricted' => false,
                             'uploadDate' => '2016-02-04'
                           } },
                         { 'id' => '23456789-ABCD-0123-cdef-987654321ABC', 'type' => 'decisionLetter',
                           'attributes' => {
                             'seriesId' => '23456789-ABCD-0123-cdef-987654321ABC',
                             'version' => nil,
                             'typeDescription' => 'Board decision',
                             'typeId' => '27',
                             'docType' => '27',
                             'subject' => 'string',
                             'receivedAt' => '2015-02-04',
                             'source' => 'Lighthouse Benefits Documents claims-letters/search',
                             'mimeType' => 'application/pdf',
                             'altDocTypes' => nil,
                             'restricted' => false,
                             'uploadDate' => '2015-02-04'
                           } }] }
          end

          before do
            allow(Flipper).to receive(:enabled?).with(:mobile_filter_doc_27_decision_letters_out).and_return(false)
          end

          it 'returns expected decision letters' do
            get '/mobile/v0/claims/decision-letters', headers: sis_headers
            assert_schema_conform(200)
            expect(response.body).to match_json_schema('decision_letter')
            expect(response.parsed_body).to eq(claim_letter_doc_response)
          end
        end
      end

      context 'when Lighthouse Benefits Documents returns 500' do
        it 'raises 502 (Bad Gateway)' do
          lighthouse_provider_double = double
          allow(lighthouse_provider_double).to receive(:get_letters).and_raise(
            Common::Exceptions::ExternalServerInternalServerError.new
          )
          allow(LighthouseClaimLettersProvider).to receive(:new).and_return(lighthouse_provider_double)
          get '/mobile/v0/claims/decision-letters', headers: sis_headers
          assert_schema_conform(502)
          expect(response.parsed_body.dig('errors', 0, 'title')).to eq('Bad Gateway')
          expect(response.parsed_body.dig('errors', 0, 'source')).to eq('DecisionLettersController#index')
        end
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
    context 'with cst_claim_letters_use_lighthouse_api_provider_mobile flag enabled' do
      let(:document_id) { '27832B64-2D88-4DEE-9F6F-DF80E4CAAA87' }
      let(:content) { File.read('spec/fixtures/files/error_message.txt') }

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:cst_claim_letters_use_lighthouse_api_provider_mobile, anything)
          .and_return(true)

        lighthouse_claim_letters_provider_double = double
        allow(LighthouseClaimLettersProvider).to receive(:new).and_return(lighthouse_claim_letters_provider_double)
        allow(lighthouse_claim_letters_provider_double).to receive(:get_letter)
          .with(document_id.to_s).and_yield(content, 'application/pdf', 'attachment', 'test')
      end

      it 'retrieves a single letter based on document id' do
        get "/mobile/v0/claims/decision-letters/#{document_id}/download", headers: sis_headers
        assert_schema_conform(200)
        expect(response.body).to eq(content)
        expect(response.headers['Content-Disposition']).to eq("attachment; filename=\"test\"; filename*=UTF-8''test")
        expect(response.headers['Content-Type']).to eq('application/pdf')
      end
    end

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

    context 'when Lighthouse Benefits Documents returns 500' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:cst_claim_letters_use_lighthouse_api_provider_mobile, anything)
          .and_return(true)
      end

      it 'raises 502 (Bad Gateway)' do
        lighthouse_provider_double = double
        allow(lighthouse_provider_double).to receive(:get_letter).and_raise(Common::Exceptions::ExternalServerInternalServerError.new)
        allow(LighthouseClaimLettersProvider).to receive(:new).and_return(lighthouse_provider_double)
        get '/mobile/v0/claims/decision-letters/27832B64-2D88-4DEE-9F6F-DF80E4CAAA87/download', headers: sis_headers
        assert_schema_conform(502)
        expect(response.parsed_body.dig('errors', 0, 'title')).to eq('Bad Gateway')
        expect(response.parsed_body.dig('errors', 0, 'source')).to eq('DecisionLettersController#download')
      end
    end
  end
end
