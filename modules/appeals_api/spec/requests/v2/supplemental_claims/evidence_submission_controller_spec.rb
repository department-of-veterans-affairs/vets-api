# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V2::DecisionReviews::SupplementalClaims::EvidenceSubmissionsController, type: :request do
  include FixtureHelpers
  let(:supplemental_claim) { create(:supplemental_claim) }
  let(:headers) { fixture_as_json 'valid_10182_headers.json' }
  let(:evidence_submissions) { create_list(:evidence_submission, 3, supportable: supplemental_claim) }
  let(:path) { '/services/appeals/v2/decision_reviews/supplemental_claims/evidence_submissions/' }

  let(:parsed) { JSON.parse(response.body) }

  def with_s3_settings
    with_settings(Settings.modules_appeals_api.evidence_submissions.location,
                  prefix: 'http://some.fakesite.com/path',
                  replacement: 'http://another.fakesite.com/rewrittenpath') do
                    s3_client = instance_double(Aws::S3::Resource)
                    allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
                    s3_bucket = instance_double(Aws::S3::Bucket)
                    s3_object = instance_double(Aws::S3::Object)
                    allow(s3_client).to receive(:bucket).and_return(s3_bucket)
                    allow(s3_bucket).to receive(:object).and_return(s3_object)
                    allow(s3_object).to receive(:presigned_url).and_return(+'http://some.fakesite.com/path/uuid')
                    yield
                  end
  end

  describe '#create' do
    context 'when corresponding supplemental_claim record not found' do
      it 'returns an error' do
        with_s3_settings do
          post path, params: { sc_uuid: 1979 }, headers: headers

          expect(response.status).to eq 404
          expect(response.body).to include 'not found'
        end
      end
    end

    context 'when corresponding supplemental_claim record found' do
      it 'returns an error if location cannot be generated' do
        with_settings(Settings.modules_appeals_api.evidence_submissions.location,
                      prefix: 'http://some.fakesite.com/path',
                      replacement: 'http://another.fakesite.com/rewrittenpath') do
                        s3_client = instance_double(Aws::S3::Resource)
                        allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
                        s3_bucket = instance_double(Aws::S3::Bucket)
                        s3_object = instance_double(Aws::S3::Object)
                        allow(s3_client).to receive(:bucket).and_return(s3_bucket)
                        allow(s3_bucket).to receive(:object).and_return(s3_object)
                        allow(s3_object).to receive(:presigned_url).and_return(+'https://nope/')
                        post path, params: { sc_uuid: supplemental_claim.id }, headers: headers

                        expect(response.status).to eq 500
                        expect(response.body).to include('Unable to provide document upload location')
                      end
      end
    end

    it "returns an error when 'sc_uuid' parameter is missing" do
      with_s3_settings do
        post path, headers: headers

        expect(response.status).to eq 400
        expect(response.body).to include 'Must supply a corresponding SupplementalClaim'
      end
    end
  end

  describe '#show' do
    it 'successfully requests the evidence submission' do
      get "#{path}#{evidence_submissions.sample.guid}"
      expect(response).to have_http_status(:ok)
    end

    it 'allow for status simulation' do
      with_settings(Settings, vsp_environment: 'development') do
        with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
          es = evidence_submissions.sample
          status_simulation_headers = { 'Status-Simulation' => 'error' }
          get "#{path}#{es.guid}", headers: status_simulation_headers
          submission = JSON.parse(response.body)
          expect(submission.dig('data', 'attributes', 'status')).to eq('error')
        end
      end
    end

    it 'returns details for the evidence submission' do
      es = evidence_submissions.sample
      sc_uuid = es.supportable_id
      get "#{path}#{es.guid}"
      submission = JSON.parse(response.body)['data']

      expect(submission['id']).to eq es.guid
      expect(submission['type']).to eq('evidenceSubmission')
      expect(submission['attributes']['status']).to eq('pending')
      expect(submission['attributes']['appealId']).to eq(sc_uuid)
      expect(submission['attributes']['appealType']).to eq('SupplementalClaim')
    end

    it 'returns an error if record is not found' do
      get "#{path}/bueller"
      expect(response.status).to eq 404
      expect(response.body).to include 'Record not found'
    end
  end
end
