# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::EvidenceSubmissionsController, type: :request do
  include FixtureHelpers
  let(:notice_of_disagreement) { create(:notice_of_disagreement, :board_review_hearing) }
  let(:headers) { fixture_as_json 'valid_10182_headers.json' }
  let(:evidence_submissions) { create_list(:evidence_submission, 3, supportable: notice_of_disagreement) }
  let(:path) { '/services/appeals/v1/decision_reviews/notice_of_disagreements/evidence_submissions/' }

  describe '#create' do
    context 'when corresponding notice of disagreement record not found' do
      it 'returns an error' do
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

          post(path, params: { nod_id: 1979, headers: headers })

          expect(response.status).to eq 404
          expect(response.body).to include 'Record not found'
        end
      end
    end

    context 'when corresponding notice of disagreement record found' do
      it "returns an error if nod 'boardReviewOption' is not 'evidence_submission'" do
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

          post(path, params: { nod_id: notice_of_disagreement.id, headers: headers })

          expect(response.status).to eq 500
          expect(response.body).to include "'boardReviewOption' must be 'evidence_submission'"
        end
      end

      it "returns an error if request 'headers['X-VA-SSN'] and NOD record SSNs do not match" do
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

          notice_of_disagreement.update(board_review_option: 'evidence_submission')
          headers['X-VA-SSN'] = "1111111111"

          post(path, params: { nod_id: notice_of_disagreement.id, headers: headers })

          expect(response.status).to eq 500
          expect(response.body).to include "'X-VA-SSN' does not match"
        end
      end

      it 'creates the evidence submission and returns upload location' do
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

          notice_of_disagreement.update(board_review_option: 'evidence_submission')
          post(path, params: { nod_id: notice_of_disagreement.id, headers: headers })

          data = JSON.parse(response.body)['data']

          expect(data).to have_key('id')
          expect(data).to have_key('type')
          expect(data['attributes']['status']).to eq('pending')
          expect(data['attributes']['appealId']).to eq(notice_of_disagreement.id)
          expect(data['attributes']['appealType']).to eq('NoticeOfDisagreement')
          expect(data['attributes']['location']).to eq('http://another.fakesite.com/rewrittenpath/uuid')
        end
      end
    end

    it "returns an error when 'nod_id' parameter is missing" do
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

        post(path, params: { headers: headers })

        expect(response.status).to eq 400
        expect(response.body).to include 'Missing parameter'
      end
    end

    it 'stores the source from headers' do
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
        notice_of_disagreement.update(board_review_option: 'evidence_submission')
        post path, params: { nod_id: notice_of_disagreement.id }, headers: headers

        data = JSON.parse(response.body)['data']
        record = AppealsApi::EvidenceSubmission.find_by(guid: data['id'])
        expect(record.source).to eq headers['X-Consumer-Username']
      end
    end
  end

  describe '#show' do
    it 'successfully requests the evidence submission' do
      get "#{path}#{evidence_submissions.sample.guid}"
      expect(response).to have_http_status(:ok)
    end

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
end
