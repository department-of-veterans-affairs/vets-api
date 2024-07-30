# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::Form4142Submit, type: :job do
  include DecisionReviewV1::Appeals::Helpers

  subject { described_class }

  around do |example|
    Sidekiq::Testing.inline!(&example)
  end

  describe 'perform' do
    let(:submitted_appeal_uuid) { 'e076ea91-6b99-4912-bffc-a8318b9b403f' }
    let(:appeal_submission) do
      create(:appeal_submission, :with_one_upload, submitted_appeal_uuid:)
    end
    let(:user) { build(:user, :loa3) }
    let(:request_body) { VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV') }

    context 'when form4142 data exists' do
      context 'and feature flag is disabled' do
        before do
          Flipper.disable :decision_review_sc_use_lighthouse_api_for_form4142
        end

        it 'generates a 4142 PDF and sends it to central mail' do
          VCR.use_cassette('central_mail/submit_4142') do
            expect do
              form4142 = request_body['form4142']
              payload = get_and_rejigger_required_info(
                request_body:, form4142:, user:
              )
              enc_payload = payload_encrypted_string(payload)
              subject.perform_async(appeal_submission.id, enc_payload, submitted_appeal_uuid)
              subject.drain
            end.to trigger_statsd_increment('worker.decision_review.form4142_submit.success', times: 1)
              .and trigger_statsd_increment('api.central_mail.upload.total', times: 1)
              .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_Form4142Submit.enqueue', times: 1)
              .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_Form4142Submit.dequeue', times: 1)
          end
        end
      end

      context 'and feature flag is enabled' do
        before do
          Flipper.enable :decision_review_sc_use_lighthouse_api_for_form4142
        end

        it '#decrypt_form properly decrypts encrypted payloads' do
          form4142 = request_body['form4142']
          payload = get_and_rejigger_required_info(
            request_body:, form4142:, user:
          )
          enc_payload = payload_encrypted_string(payload)
          expect(subject.new.decrypt_form(enc_payload)).to eq(payload)
        end

        it 'generates a 4142 PDF and sends it to Lighthouse API' do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
              expect do
                form4142 = request_body['form4142']
                payload = get_and_rejigger_required_info(
                  request_body:, form4142:, user:
                )
                enc_payload = payload_encrypted_string(payload)
                subject.perform_async(appeal_submission.id, enc_payload, submitted_appeal_uuid)
                subject.drain
              end.to trigger_statsd_increment('worker.decision_review.form4142_submit.success', times: 1)
                .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_Form4142Submit.enqueue',
                                              times: 1)
                .and trigger_statsd_increment('shared.sidekiq.default.DecisionReview_Form4142Submit.dequeue',
                                              times: 1)
            end
          end
        end
      end
    end
  end
end
