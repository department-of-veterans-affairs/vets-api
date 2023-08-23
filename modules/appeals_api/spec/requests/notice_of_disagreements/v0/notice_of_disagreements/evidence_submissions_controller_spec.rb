# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreements::EvidenceSubmissionsController, type: :request do
  include FixtureHelpers
  let(:notice_of_disagreement) { create(:notice_of_disagreement_v0, :board_review_evidence_submission) }

  def stub_upload_location(expected_location = 'http://some.fakesite.com/path/uuid')
    allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:get_location).and_return(expected_location)
  end

  describe '#show' do
    let(:evidence_submissions) { create_list(:evidence_submission, 3, supportable: notice_of_disagreement) }
    let(:response_data) { JSON.parse(response.body)&.dig('data') }
    let(:guid) { evidence_submissions.sample.guid }
    let(:path) { "/services/appeals/notice-of-disagreements/v0/evidence-submissions/#{guid}" }

    describe 'responses' do
      before do
        stub_upload_location
        with_openid_auth(described_class::OAUTH_SCOPES[:GET]) { |auth_header| get(path, headers: auth_header) }
      end

      context 'success' do
        it 'returns details for the evidence submission' do
          expect(response).to have_http_status(:ok)
          expect(response_data['id']).to eq(guid)
          expect(response_data['type']).to eq('evidenceSubmission')
          expect(response_data['attributes']['status']).to eq('pending')
          expect(response_data['attributes']['appealId']).to eq(notice_of_disagreement.id)
          expect(response_data['attributes']['appealType']).to eq('NoticeOfDisagreement')
        end
      end

      context 'when the record is not found' do
        let(:guid) { '00000000-0000-0000-0000-000000000000' }

        it 'returns a 404' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    describe 'auth behavior' do
      it_behaves_like('an endpoint with OpenID auth', scopes: described_class::OAUTH_SCOPES[:GET]) do
        def make_request(auth_header) = get(path, headers: auth_header)
      end
    end
  end

  describe '#create' do
    let(:consumer_username) { 'test' }
    let(:file_number) { notice_of_disagreement.veteran.file_number }
    let(:nod_id) { notice_of_disagreement.id }
    let(:params) { { fileNumber: file_number, nodId: nod_id } }
    let(:headers) { { 'X-Consumer-Username' => consumer_username, 'Content-Type' => 'application/json' } }
    let(:path) { '/services/appeals/notice-of-disagreements/v0/evidence-submissions' }
    let(:response_data) { JSON.parse(response.body)&.dig('data') }

    before do
      stub_upload_location
      with_openid_auth(described_class::OAUTH_SCOPES[:POST]) do |auth_header|
        post(path, params: params.to_json, headers: headers.merge(auth_header))
      end
    end

    describe 'responses' do
      describe 'successes' do
        context 'when provided fileNumber matches the NOD' do
          it 'succeeds and store the source on the submission record' do
            expect(response).to have_http_status(:accepted)

            updated_record = AppealsApi::EvidenceSubmission.find_by(guid: response_data['id'])
            expect(updated_record.source).to eq consumer_username
          end
        end

        context 'when PII has already been expunged from the NOD record' do
          let(:notice_of_disagreement) do
            nod = create(:notice_of_disagreement_v0, :board_review_evidence_submission)
            nod.update!(auth_headers: nil, form_data: nil)
            nod
          end

          it 'succeeds anyway' do
            expect(response).to have_http_status(:accepted)
          end
        end
      end

      describe 'errors' do
        context 'when the corresponding notice of disagreement is not found' do
          let(:nod_id) { '111111111111-1111-1111-1111-11111111' }

          it 'returns a 404 error' do
            expect(response).to have_http_status(:not_found)
          end
        end

        context 'when the File Number provided does not match the File Number on the NOD record' do
          let(:file_number) { '000000000' }

          it 'returns a 422 error' do
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        context 'when File Number is missing' do
          let(:file_number) {}

          it 'returns a 422 error' do
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end

        context 'when NOD UUID is missing' do
          let(:nod_id) {}

          it 'returns a 422 error' do
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end

    it_behaves_like(
      'an endpoint with OpenID auth',
      scopes: described_class::OAUTH_SCOPES[:POST],
      success_status: :accepted
    ) do
      def make_request(auth_header)
        post(path, params: params.to_json, headers: headers.merge(auth_header))
      end
    end
  end
end
