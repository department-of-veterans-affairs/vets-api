# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::V1::DecisionReviews::NoticeOfDisagreements::EvidenceSubmissionsController, type: :request do
  include FixtureHelpers

  let!(:notice_of_disagreement) { create(:notice_of_disagreement) }
  let!(:evidence_submissions) { create_list(:evidence_submission, 3, supportable: notice_of_disagreement) }
  let(:path) { '/services/appeals/v1/decision_reviews/notice_of_disagreements/evidence_submissions/' }

  describe '#show' do
    it 'successfully requests the evidence submissions' do
      get "#{path}#{notice_of_disagreement.id}"

      expect(response).to have_http_status(:ok)
    end

    it 'queries all evidence submissions for the nod' do
      get "#{path}#{notice_of_disagreement.id}"
      body = JSON.parse(response.body)['data']
      body.each do |submission|
        expect(submission).to have_key('id')
        expect(submission).to have_key('type')
        expect(submission['attributes']['status']).to eq('pending')
        expect(submission['attributes']['appealId']).to eq(notice_of_disagreement.id)
        expect(submission['attributes']['appealType']).to eq('NoticeOfDisagreement')
      end
    end
  end

  describe '#create' do
    let(:double_setup) do
      s3_client = instance_double(Aws::S3::Resource)
      allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
      s3_bucket = instance_double(Aws::S3::Bucket)
      s3_object = instance_double(Aws::S3::Object)
      allow(s3_client).to receive(:bucket).and_return(s3_bucket)
      allow(s3_bucket).to receive(:object).and_return(s3_object)
      allow(s3_object).to receive(:presigned_url).and_return(+'https://fake.s3.url/foo/uuid')
    end

    it 'returns submission attributes and location url' do
      with_settings(Settings.modules_appeals_api.evidence_submissions.location,
                    prefix: 'https://fake.s3.url/foo/',
                    replacement: 'https://api.vets.gov/proxy/') do
        double_setup
        post(path, params: { nod_id: notice_of_disagreement.id })
        body = JSON.parse(response.body)['data']
        expect(body).to have_key('id')
        expect(body).to have_key('type')
        expect(body['attributes']['status']).to eq('pending')
        expect(body['attributes']['appealId']).to eq(notice_of_disagreement.id)
        expect(body['attributes']['appealType']).to eq('NoticeOfDisagreement')
        expect(body['attributes']['location']).to eq('https://api.vets.gov/proxy/uuid')
      end
    end

    context 'with no matching record' do
      it 'raises an error' do
        with_settings(Settings.modules_appeals_api.evidence_submissions.location,
                      prefix: 'https://fake.s3.url/foo/',
                      replacement: 'https://api.vets.gov/proxy/') do
          double_setup
          post(path, params: { nod_id: 1979 })
          expect(response.status).to eq 404
          expect(response.body).to include 'Record not found'
        end
      end
    end
  end
end
