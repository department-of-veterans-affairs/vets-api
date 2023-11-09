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
  end
end
