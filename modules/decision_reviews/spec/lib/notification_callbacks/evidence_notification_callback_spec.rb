# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require 'decision_reviews/notification_callbacks/evidence_notification_callback'

describe DecisionReviews::EvidenceNotificationCallback do
  subject { described_class }

  let(:reference) { "SC-evidence-#{SecureRandom.uuid}" }
  let(:submitted_appeal_uuid) { SecureRandom.uuid }

  let(:email_template_id) do
    Settings.vanotify.services.benefits_decision_review.template_id.supplemental_claim_evidence_error_email
  end

  let(:notification) do
    OpenStruct.new(
      notification_id: SecureRandom.uuid,
      notification_type: 'email',
      source_location: 'unit-test',
      reference:,
      status:,
      status_reason:,
      callback_klass: described_class.to_s,
      callback_metadata: {
        email_type: :error,
        service_name: 'supplemental-claims',
        function: 'evidence submission to lighthouse',
        submitted_appeal_uuid:,
        email_template_id:
      }
    )
  end

  before do
    allow(DecisionReviewNotificationAuditLog).to receive(:create!)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:info)
  end

  context 'when the notification is delivered' do
    let(:status) { 'delivered' }
    let(:status_reason) { 'success' }

    it 'records and logs a successful form notification delivery' do
      expect(Rails.logger).to receive(:error) do |message, payload|
        expect(message).to eq('Silent failure avoided')
        expect(payload[:service]).to eq('supplemental-claims')
        expect(payload[:function]).to eq('evidence submission to lighthouse')
        expect(payload[:additional_context][:callback_metadata][:submitted_appeal_uuid]).to eq(submitted_appeal_uuid)
      end
      expect(Rails.logger).to receive(:info).with('DecisionReviews::EvidenceNotificationCallback: Delivered',
                                                  anything)

      subject.call(notification)

      expect(DecisionReviewNotificationAuditLog).to have_received(:create!).with(
        notification_id: notification.notification_id,
        reference:,
        status:,
        payload: notification.to_json
      )

      expect(StatsD).to have_received(:increment).with('api.veteran_facing_services.notification.callback.delivered',
                                                       tags: ['service:supplemental-claims',
                                                              'function:evidence submission to lighthouse'])
                                                 .exactly(1).time
      expect(StatsD).to have_received(:increment).with('silent_failure_avoided',
                                                       tags: ['service:supplemental-claims',
                                                              'function:evidence submission to lighthouse'])
                                                 .exactly(1).time
    end
  end

  context 'when the notification permanently fails' do
    let(:status) { 'permanent-failure' }
    let(:status_reason) { 'failure' }

    it 'records and logs a permanently failed form notification delivery' do
      expect(Rails.logger).to receive(:error) do |message, payload|
        expect(message).to eq('Silent failure!')
        expect(payload[:service]).to eq('supplemental-claims')
        expect(payload[:function]).to eq('evidence submission to lighthouse')
        expect(payload[:additional_context][:callback_metadata][:submitted_appeal_uuid]).to eq(submitted_appeal_uuid)
      end
      expect(Rails.logger).to receive(:error).with('DecisionReviews::EvidenceNotificationCallback: Permanent Failure',
                                                   anything)

      subject.call(notification)

      expect(DecisionReviewNotificationAuditLog).to have_received(:create!).with(
        notification_id: notification.notification_id,
        reference:,
        status:,
        payload: notification.to_json
      )

      expect(StatsD).to have_received(:increment).with('api.veteran_facing_services.notification.callback.permanent_failure', # rubocop:disable Layout/LineLength
                                                       tags: ['service:supplemental-claims',
                                                              'function:evidence submission to lighthouse'])
                                                 .exactly(1).time
      expect(StatsD).to have_received(:increment).with('silent_failure',
                                                       tags: ['service:supplemental-claims',
                                                              'function:evidence submission to lighthouse'])
                                                 .exactly(1).time
    end
  end

  context 'when the notification temporarily fails' do
    let(:status) { 'temporary-failure' }
    let(:status_reason) { 'success' }

    it 'records and logs a temporarily failed form notification delivery' do
      expect(Rails.logger).to receive(:warn).with('DecisionReviews::EvidenceNotificationCallback: Temporary Failure',
                                                  anything)

      subject.call(notification)

      expect(DecisionReviewNotificationAuditLog).to have_received(:create!).with(
        notification_id: notification.notification_id,
        reference:,
        status: 'temporary-failure',
        payload: notification.to_json
      )

      expect(StatsD).to have_received(:increment).with('api.veteran_facing_services.notification.callback.temporary_failure', # rubocop:disable Layout/LineLength
                                                       tags: ['service:supplemental-claims',
                                                              'function:evidence submission to lighthouse'])
                                                 .exactly(1).time
    end
  end

  context 'when the notification has some other status' do
    let(:status) { 'other' }
    let(:status_reason) { 'unknown' }

    it 'records an audit log for the other status' do
      expect(Rails.logger).to receive(:warn).with('DecisionReviews::EvidenceNotificationCallback: Other',
                                                  anything)

      subject.call(notification)

      expect(DecisionReviewNotificationAuditLog).to have_received(:create!).with(
        notification_id: notification.notification_id,
        reference:,
        status: 'other',
        payload: notification.to_json
      )
    end
  end
end
