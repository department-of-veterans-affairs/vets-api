# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::SubmitUpload, type: :job do
  subject { described_class }

  around do |example|
    Sidekiq::Testing.inline!(&example)
  end

  describe 'perform' do
    let(:appeal_submission) do
      create(:appeal_submission, :with_one_upload, submitted_appeal_uuid: 'e076ea91-6b99-4912-bffc-a8318b9b403f')
    end
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', Mime[:pdf].to_s) }
    let(:appeal_submission_upload) { appeal_submission.appeal_submission_uploads.first }
    let(:expect_uploaded_url) { 'https://sandbox-api.va.gov/services_user_content/vba_documents/832a96ca-4dbd-4138-b7a4-6a991ff76faf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAQD72FDTFWPUWR5OZ/20210521/us-gov-west-1/s3/aws4_request&X-Amz-Date=20210521T193313Z&X-Amz-Expires=900&X-Amz-Signature=5d64a8a7fd749b1fb301a43226d45cc865fb68e6397026bdf047737c05fa4927&X-Amz-SignedHeaders=host' }
    let(:upload_retrieval_success_log) do
      {
        message: 'Evidence upload retrieval success!',
        user_uuid: appeal_submission.user_uuid,
        action: 'Evidence upload retrieval',
        form_id: '10182',
        upstream_system: 'AWS S3',
        downstream_system: nil,
        is_success: true,
        http: {
          status_code: nil,
          body: nil
        },
        appeal_submission_upload_id: appeal_submission_upload.id,
        form_attachment_id: attachment.id
      }
    end
    let(:upload_retrieval_failure_log) do
      {
        message: 'Evidence upload retrieval failure!',
        user_uuid: appeal_submission.user_uuid,
        action: 'Evidence upload retrieval',
        form_id: '10182',
        upstream_system: 'AWS S3',
        downstream_system: nil,
        is_success: false,
        http: {
          status_code: nil,
          body: 'Error!'
        },
        appeal_submission_upload_id: appeal_submission_upload.id,
        form_attachment_id: attachment.id
      }
    end
    let(:get_lighthouse_url_success_log) do
      {
        message: 'Get lighthouse evidence upload url success!',
        user_uuid: appeal_submission.user_uuid,
        action: 'Get lighthouse evidence upload url',
        form_id: '10182',
        upstream_system: 'Lighthouse',
        downstream_system: 'Lighthouse',
        is_success: true,
        http: {
          status_code: 200,
          body: anything
        },
        nod_uuid: appeal_submission.submitted_appeal_uuid,
        appeal_submission_upload_id: appeal_submission_upload.id
      }
    end
    let(:get_lighthouse_url_failure_log) do
      {
        message: 'Get lighthouse evidence upload url failure!',
        user_uuid: appeal_submission.user_uuid,
        action: 'Get lighthouse evidence upload url',
        form_id: '10182',
        upstream_system: 'Lighthouse',
        downstream_system: 'Lighthouse',
        is_success: false,
        http: {
          status_code: 503,
          body: anything
        },
        nod_uuid: appeal_submission.submitted_appeal_uuid,
        appeal_submission_upload_id: appeal_submission_upload.id
      }
    end
    let(:upload_lighthouse_success_log) do
      {
        message: 'Evidence upload to lighthouse success!',
        user_uuid: appeal_submission.user_uuid,
        action: 'Evidence upload to lighthouse',
        form_id: '10182',
        upstream_system: nil,
        downstream_system: 'Lighthouse',
        is_success: true,
        http: {
          status_code: 200,
          body: '[Redacted]'
        },
        upload_url: expect_uploaded_url,
        appeal_submission_upload_id: appeal_submission_upload.id
      }
    end
    let(:upload_lighthouse_failure_log) do
      {
        message: 'Evidence upload to lighthouse failure!',
        user_uuid: appeal_submission.user_uuid,
        action: 'Evidence upload to lighthouse',
        form_id: '10182',
        upstream_system: nil,
        downstream_system: 'Lighthouse',
        is_success: false,
        http: {
          status_code: 503,
          body: anything
        },
        upload_url: expect_uploaded_url,
        appeal_submission_upload_id: appeal_submission_upload.id
      }
    end

    context 'NOD - when file_data exists' do
      let!(:attachment) do
        VCR.use_cassette('decision_review/200_pdf_validation') do
          drea = DecisionReviewEvidenceAttachment.new(
            guid: appeal_submission_upload.decision_review_evidence_attachment_guid
          )
          drea.set_file_data!(file)
          drea.save!
          drea
        end
      end

      it 'calls the documents service api with file body and document data (for NOD)' do
        VCR.use_cassette('decision_review/NOD-GET-UPLOAD-URL-200_V1') do
          VCR.use_cassette('decision_review/NOD-PUT-UPLOAD-200') do
            VCR.use_cassette('decision_review/200_pdf_validation') do
              allow(Rails.logger).to receive(:info)
              expect(Rails.logger).to receive(:info).with(upload_retrieval_success_log)
              expect(Rails.logger).to receive(:info).with(get_lighthouse_url_success_log)
              expect(Rails.logger).to receive(:info).with(upload_lighthouse_success_log)

              expect do
                subject.perform_async(appeal_submission_upload.id)
                subject.drain
              end.to trigger_statsd_increment('api.decision_review.get_notice_of_disagreement_upload_url.total',
                                              times: 1)
                .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.enqueue', times: 1)
                .and trigger_statsd_increment('api.decision_review.get_notice_of_disagreement_upload_url.total',
                                              times: 1)
                .and trigger_statsd_increment('api.decision_review.put_notice_of_disagreement_upload.total', times: 1)
                .and trigger_statsd_increment('worker.decision_review.submit_upload.success', times: 1)
                .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.dequeue', times: 1)
                .and trigger_statsd_increment('decision_review.form_10182.evidence_upload_retrieval.success', times: 1)
                .and trigger_statsd_increment('decision_review.form_10182.get_lighthouse_evidence_upload_url.success',
                                              times: 1)
                .and trigger_statsd_increment('decision_review.form_10182.evidence_upload_to_lighthouse.success',
                                              times: 1)
              expect(AppealSubmissionUpload.first.lighthouse_upload_id).to eq('59cdb98f-f94b-4aaa-8952-4d1e59b6e40a')
            end
          end
        end
      end

      context 'Evidence upload retrieval throws an error' do
        it 'surfaces error in logs and StatsD' do
          VCR.use_cassette('decision_review/NOD-GET-UPLOAD-URL-200_V1') do
            VCR.use_cassette('decision_review/NOD-PUT-UPLOAD-200') do
              VCR.use_cassette('decision_review/200_pdf_validation') do
                expect_any_instance_of(FormAttachment).to receive(:get_file).and_raise('Error!')
                allow(Rails.logger).to receive(:error)
                expect(Rails.logger).to receive(:error).with(upload_retrieval_failure_log)
                expect do
                  subject.perform_async(appeal_submission_upload.id)
                  subject.drain
                end.to raise_error('Error!')
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.enqueue', times: 1)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.dequeue', times: 1)
                  .and trigger_statsd_increment('decision_review.form_10182.evidence_upload_retrieval.failure',
                                                times: 1)
                  .and trigger_statsd_increment('worker.decision_review.submit_upload.error', times: 1)
                expect(AppealSubmissionUpload.first.lighthouse_upload_id).to be_nil
              end
            end
          end
        end
      end

      context 'Fetching Lighthouse evidence upload url fails' do
        it 'surfaces error in logs and StatsD' do
          VCR.use_cassette('decision_review/NOD-GET-UPLOAD-URL-503_V1') do
            VCR.use_cassette('decision_review/NOD-PUT-UPLOAD-200') do
              VCR.use_cassette('decision_review/200_pdf_validation') do
                allow(Rails.logger).to receive(:error)
                expect(Rails.logger).to receive(:error).with(get_lighthouse_url_failure_log)
                expect do
                  subject.perform_async(appeal_submission_upload.id)
                  subject.drain
                end.to raise_error(DecisionReviewV1::ServiceException)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.enqueue', times: 1)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.dequeue', times: 1)
                  .and trigger_statsd_increment('decision_review.form_10182.evidence_upload_retrieval.success',
                                                times: 1)
                  .and trigger_statsd_increment(
                    'decision_review.form_10182.get_lighthouse_evidence_upload_url.failure', times: 1
                  )
                  .and trigger_statsd_increment('worker.decision_review.submit_upload.error', times: 1)
                expect(AppealSubmissionUpload.first.lighthouse_upload_id).to be_nil
              end
            end
          end
        end
      end

      context 'Evidence upload to Lighthouse fails' do
        it 'surfaces error in logs and StatsD' do
          VCR.use_cassette('decision_review/NOD-GET-UPLOAD-URL-200_V1') do
            VCR.use_cassette('decision_review/NOD-PUT-UPLOAD-503') do
              VCR.use_cassette('decision_review/200_pdf_validation') do
                allow(Rails.logger).to receive(:error)
                expect(Rails.logger).to receive(:error).with(upload_lighthouse_failure_log)
                expect do
                  subject.perform_async(appeal_submission_upload.id)
                  subject.drain
                end.to raise_error(DecisionReviewV1::ServiceException)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.enqueue', times: 1)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.dequeue', times: 1)
                  .and trigger_statsd_increment('decision_review.form_10182.evidence_upload_retrieval.success',
                                                times: 1)
                  .and trigger_statsd_increment(
                    'decision_review.form_10182.get_lighthouse_evidence_upload_url.success', times: 1
                  )
                  .and trigger_statsd_increment('decision_review.form_10182.evidence_upload_to_lighthouse.failure',
                                                times: 1)
                  .and trigger_statsd_increment('worker.decision_review.submit_upload.error', times: 1)
                expect(AppealSubmissionUpload.first.lighthouse_upload_id).to be_nil
              end
            end
          end
        end
      end

      it 'increments statsd when job fails permanently' do
        msg = {
          'jid' => 'job_id',
          'args' => [appeal_submission_upload.id],
          'error_message' => 'An error occurred for sidekiq job'
        }

        tags = ['service:board-appeal', 'function: evidence submission to Lighthouse']

        expect { described_class.new.sidekiq_retries_exhausted_block.call(msg) }
          .to trigger_statsd_increment('worker.decision_review.submit_upload.permanent_error')
          .and trigger_statsd_increment('silent_failure', tags:)
      end
    end

    context 'Supplemental Claims - when file_data exists' do
      let!(:attachment) do
        VCR.use_cassette('decision_review/200_pdf_validation') do
          drea = DecisionReviewEvidenceAttachment.new(
            guid: appeal_submission_upload.decision_review_evidence_attachment_guid
          )
          drea.set_file_data!(file)
          drea.save!
          drea
        end
      end

      before do
        appeal_submission.update(type_of_appeal: 'SC')
      end

      it 'calls the documents service api with file body and document data (for SC)' do
        VCR.use_cassette('decision_review/SC-GET-UPLOAD-URL-200_V1') do
          VCR.use_cassette('decision_review/SC-PUT-UPLOAD-200_V1') do
            VCR.use_cassette('decision_review/200_pdf_validation') do
              # prep expected logs
              upload_retrieval_success_log[:form_id] = '995'
              get_lighthouse_url_success_log[:form_id] = '995'
              get_lighthouse_url_success_log.delete(:nod_uuid)
              get_lighthouse_url_success_log[:sc_uuid] = appeal_submission.submitted_appeal_uuid
              upload_lighthouse_success_log[:form_id] = '995'

              allow(Rails.logger).to receive(:info)
              expect(Rails.logger).to receive(:info).with(upload_retrieval_success_log)
              expect(Rails.logger).to receive(:info).with(get_lighthouse_url_success_log)
              expect(Rails.logger).to receive(:info).with(upload_lighthouse_success_log)

              expect do
                subject.perform_async(appeal_submission_upload.id)
                subject.drain
              end.to trigger_statsd_increment('api.decision_review.get_supplemental_claim_upload_url.total',
                                              times: 1)
                .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.enqueue', times: 1)
                .and trigger_statsd_increment('api.decision_review.get_supplemental_claim_upload_url.total',
                                              times: 1)
                .and trigger_statsd_increment('api.decision_review.put_supplemental_claim_upload.total', times: 1)
                .and trigger_statsd_increment('worker.decision_review.submit_upload.success', times: 1)
                .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.dequeue', times: 1)
                .and trigger_statsd_increment('decision_review.form_995.evidence_upload_retrieval.success', times: 1)
                .and trigger_statsd_increment('decision_review.form_995.get_lighthouse_evidence_upload_url.success',
                                              times: 1)
                .and trigger_statsd_increment('decision_review.form_995.evidence_upload_to_lighthouse.success',
                                              times: 1)
              expect(AppealSubmissionUpload.first.lighthouse_upload_id).to eq('59cdb98f-f94b-4aaa-8952-4d1e59b6e40a')
            end
          end
        end
      end

      context 'Evidence upload retrieval throws an error' do
        it 'surfaces error in logs and StatsD' do
          VCR.use_cassette('decision_review/SC-GET-UPLOAD-URL-200_V1') do
            VCR.use_cassette('decision_review/SC-PUT-UPLOAD-200_V1') do
              VCR.use_cassette('decision_review/200_pdf_validation') do
                expect_any_instance_of(FormAttachment).to receive(:get_file).and_raise('Error!')
                # prep expected logs
                upload_retrieval_failure_log[:form_id] = '995'
                allow(Rails.logger).to receive(:error)
                expect(Rails.logger).to receive(:error).with(upload_retrieval_failure_log)
                expect do
                  subject.perform_async(appeal_submission_upload.id)
                  subject.drain
                end.to raise_error('Error!')
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.enqueue', times: 1)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.dequeue', times: 1)
                  .and trigger_statsd_increment('decision_review.form_995.evidence_upload_retrieval.failure',
                                                times: 1)
                  .and trigger_statsd_increment('worker.decision_review.submit_upload.error', times: 1)
                expect(AppealSubmissionUpload.first.lighthouse_upload_id).to be_nil
              end
            end
          end
        end
      end

      context 'Fetching Lighthouse evidence upload url fails' do
        it 'surfaces error in logs and StatsD' do
          VCR.use_cassette('decision_review/SC-GET-UPLOAD-URL-404_V1') do
            VCR.use_cassette('decision_review/SC-PUT-UPLOAD-200_V1') do
              VCR.use_cassette('decision_review/200_pdf_validation') do
                get_lighthouse_url_failure_log[:form_id] = '995'
                get_lighthouse_url_failure_log.delete(:nod_uuid)
                get_lighthouse_url_failure_log[:sc_uuid] = appeal_submission.submitted_appeal_uuid
                get_lighthouse_url_failure_log[:http] =
                  { status_code: 404, body: 'the server responded with status 404' }
                allow(Rails.logger).to receive(:error)
                expect(Rails.logger).to receive(:error).with(get_lighthouse_url_failure_log)
                expect do
                  subject.perform_async(appeal_submission_upload.id)
                  subject.drain
                end.to raise_error(DecisionReviewV1::ServiceException)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.enqueue', times: 1)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.dequeue', times: 1)
                  .and trigger_statsd_increment('decision_review.form_995.evidence_upload_retrieval.success',
                                                times: 1)
                  .and trigger_statsd_increment(
                    'decision_review.form_995.get_lighthouse_evidence_upload_url.failure', times: 1
                  )
                  .and trigger_statsd_increment('worker.decision_review.submit_upload.error', times: 1)
                expect(AppealSubmissionUpload.first.lighthouse_upload_id).to be_nil
              end
            end
          end
        end
      end

      context 'Evidence upload to Lighthouse fails' do
        it 'surfaces error in logs and StatsD' do
          VCR.use_cassette('decision_review/SC-GET-UPLOAD-URL-200_V1') do
            VCR.use_cassette('decision_review/SC-PUT-UPLOAD-503_V1') do
              VCR.use_cassette('decision_review/200_pdf_validation') do
                upload_lighthouse_failure_log[:form_id] = '995'
                allow(Rails.logger).to receive(:error)
                expect(Rails.logger).to receive(:error).with(upload_lighthouse_failure_log)
                expect do
                  subject.perform_async(appeal_submission_upload.id)
                  subject.drain
                end.to raise_error(DecisionReviewV1::ServiceException)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.enqueue', times: 1)
                  .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_SubmitUpload.dequeue', times: 1)
                  .and trigger_statsd_increment('decision_review.form_995.evidence_upload_retrieval.success',
                                                times: 1)
                  .and trigger_statsd_increment(
                    'decision_review.form_995.get_lighthouse_evidence_upload_url.success', times: 1
                  )
                  .and trigger_statsd_increment('decision_review.form_995.evidence_upload_to_lighthouse.failure',
                                                times: 1)
                  .and trigger_statsd_increment('worker.decision_review.submit_upload.error', times: 1)
                expect(AppealSubmissionUpload.first.lighthouse_upload_id).to be_nil
              end
            end
          end
        end
      end
    end
  end
end
