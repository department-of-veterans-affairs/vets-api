# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::EvidenceSubmissionsController, type: :request do
  include FixtureHelpers
  let(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let(:headers) { fixture_as_json 'valid_10182_headers.json' }
  let(:evidence_submissions) { create_list(:evidence_submission, 3, :for_nod) }
  let(:evidence_submission) { create(:evidence_submission, :set_supportable_type) }
  let(:path) { '/services/appeals/v1/decision_reviews/notice_of_disagreements/evidence_submissions/' }

  describe '#create' do
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
    context "when 'nod_id' is included" do
      it "returns submission attributes including 'appealId'" do
        with_s3_settings do
          post(path, params: { nod_id: notice_of_disagreement.id, headers: headers })
        end

        data = JSON.parse(response.body)['data']

        expect(data).to have_key('id')
        expect(data).to have_key('type')
        expect(data['attributes']['status']).to eq('pending')
        expect(data['attributes']['appealId']).to eq(notice_of_disagreement.id)
        expect(data['attributes']['appealType']).to eq('NoticeOfDisagreement')
        expect(data['attributes']['location']).to eq('http://another.fakesite.com/rewrittenpath/uuid')
      end

      it 'raises an error if record is not found' do
        with_s3_settings do
          post(path, params: { nod_id: SecureRandom.uuid })
          expect(response.status).to eq 404
          expect(response.body).to include 'Record not found'
        end
      end
    end

    context "when 'nod_id' is not included" do
      it 'returns submission attributes' do
        with_s3_settings do
          post(path, params: { headers: headers })
        end

        data = JSON.parse(response.body)['data']

        expect(data).to have_key('id')
        expect(data).to have_key('type')
        expect(data['attributes']['status']).to eq('pending')
        expect(data['attributes']['appealId']).to be_nil
        expect(data['attributes']['appealType']).to eq('NoticeOfDisagreement')
        expect(data['attributes']['location']).to eq('http://another.fakesite.com/rewrittenpath/uuid')
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

    context 'with associated notice of disagreement' do
      it 'returns details for the evidence submission' do
        es = evidence_submissions.sample
        nod_id = es.supportable_id
        get "#{path}#{es.guid}"
        submission = JSON.parse(response.body)['data']

        expect(submission['id']).to eq es.guid
        expect(submission['type']).to eq('evidenceSubmission')
        expect(submission['attributes']['status']).to eq('pending')
        expect(submission['attributes']['appealId']).to eq(nod_id)
        expect(submission['attributes']['appealType']).to eq('NoticeOfDisagreement')
      end

      it 'returns an error if record is not found' do
        get "#{path}/bueller"
        expect(response.status).to eq 404
        expect(response.body).to include 'Record not found'
      end
    end

    context 'without associated notice of disagreement' do
      it 'returns details for the evidence submission' do
        get "#{path}#{evidence_submission.guid}"
        submission = JSON.parse(response.body)['data']

        expect(submission['id']).to eq evidence_submission.guid
        expect(submission['type']).to eq('evidenceSubmission')
        expect(submission['attributes']['status']).to eq('pending')
        expect(submission['attributes']['appealId']).to be_nil
        expect(submission['attributes']['appealType']).to eq('NoticeOfDisagreement')
      end
    end
  end
end
