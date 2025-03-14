# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require 'decision_reviews/notification_callbacks/form_notification_callback'

describe DecisionReviews::FormNotificationCallback do
  subject { described_class }

  let(:reference) { "SC-form-#{SecureRandom.uuid}" }
  let(:submitted_appeal_uuid) { SecureRandom.uuid }

  before do
    allow(DecisionReviewNotificationAuditLog).to receive(:create!)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:info)
  end

  context 'when the notification is delivered' do
    let(:delivered_notification) do
      OpenStruct.new(
        notification_id: SecureRandom.uuid,
        notification_type: 'email',
        source_location: 'unit-test',
        reference:,
        status: 'delivered',
        status_reason: 'success',
        callback_klass: described_class.to_s,
        callback_metadata: {
          email_type: :error,
          service_name: 'supplemental-claims',
          function: 'form submission',
          submitted_appeal_uuid:,
          email_template_id: Settings.vanotify.services.benefits_decision_review.template_id.supplemental_claim_form_error_email # rubocop:disable Layout/LineLength
        }
      )
    end

    it 'records and logs a successful form notification delivery' do
      expect(Rails.logger).to receive(:error) do |message, payload|
        expect(message).to eq('Silent failure avoided')
        expect(payload[:service]).to eq('supplemental-claims')
        expect(payload[:function]).to eq('form submission')
        expect(payload[:additional_context][:callback_metadata][:submitted_appeal_uuid])
          .to eq(submitted_appeal_uuid)
      end
      expect(Rails.logger).to receive(:info).with('DecisionReviews::FormNotificationCallback: Delivered',
                                                  anything)

      subject.call(delivered_notification)

      expect(DecisionReviewNotificationAuditLog).to have_received(:create!).with(
        notification_id: delivered_notification.notification_id,
        reference:,
        status: 'delivered',
        payload: delivered_notification.to_json
      )

      expect(StatsD).to have_received(:increment).with('api.veteran_facing_services.notification.callback.delivered',
                                                       tags: ['service:supplemental-claims',
                                                              'function:form submission']).exactly(1).time
      expect(StatsD).to have_received(:increment).with('silent_failure_avoided',
                                                       tags: ['service:supplemental-claims',
                                                              'function:form submission']).exactly(1).time
    end
  end

  context 'when the notification permanently fails' do
    let(:failed_notification) do
      OpenStruct.new(
        notification_id: SecureRandom.uuid,
        notification_type: 'email',
        source_location: 'unit-test',
        reference:,
        status: 'permanent-failure',
        status_reason: 'failure',
        callback_klass: described_class.to_s,
        callback_metadata: {
          email_type: :error,
          service_name: 'supplemental-claims',
          function: 'form submission',
          submitted_appeal_uuid:,
          email_template_id: Settings.vanotify.services.benefits_decision_review.template_id.supplemental_claim_form_error_email # rubocop:disable Layout/LineLength
        }
      )
    end

    it 'records and logs a permanently failed form notification delivery' do
      expect(Rails.logger).to receive(:error) do |message, payload|
        expect(message).to eq('Silent failure!')
        expect(payload[:service]).to eq('supplemental-claims')
        expect(payload[:function]).to eq('form submission')
        expect(payload[:additional_context][:callback_metadata][:submitted_appeal_uuid])
          .to eq(submitted_appeal_uuid)
      end
      expect(Rails.logger).to receive(:error).with('DecisionReviews::FormNotificationCallback: Permanent Failure',
                                                   anything)

      subject.call(failed_notification)

      expect(DecisionReviewNotificationAuditLog).to have_received(:create!).with(
        notification_id: failed_notification.notification_id,
        reference:,
        status: 'permanent-failure',
        payload: failed_notification.to_json
      )

      expect(StatsD).to have_received(:increment).with('api.veteran_facing_services.notification.callback.permanent_failure', # rubocop:disable Layout/LineLength
                                                       tags: ['service:supplemental-claims',
                                                              'function:form submission']).exactly(1).time
      expect(StatsD).to have_received(:increment).with('silent_failure',
                                                       tags: ['service:supplemental-claims',
                                                              'function:form submission']).exactly(1).time
    end
  end

  context 'when the notification temporarily fails' do
    let(:temp_failed_notification) do
      OpenStruct.new(
        notification_id: SecureRandom.uuid,
        notification_type: 'email',
        source_location: 'unit-test',
        reference:,
        status: 'temporary-failure',
        status_reason: 'failure',
        callback_klass: described_class.to_s,
        callback_metadata: {
          email_type: :error,
          service_name: 'supplemental-claims',
          function: 'form submission',
          submitted_appeal_uuid:,
          email_template_id: Settings.vanotify.services.benefits_decision_review.template_id.supplemental_claim_form_error_email # rubocop:disable Layout/LineLength
        }
      )
    end

    it 'records and logs a temporarily failed form notification delivery' do
      expect(Rails.logger).to receive(:warn).with('DecisionReviews::FormNotificationCallback: Temporary Failure',
                                                  anything)

      subject.call(temp_failed_notification)

      expect(DecisionReviewNotificationAuditLog).to have_received(:create!).with(
        notification_id: temp_failed_notification.notification_id,
        reference:,
        status: 'temporary-failure',
        payload: temp_failed_notification.to_json
      )

      expect(StatsD).to have_received(:increment).with('api.veteran_facing_services.notification.callback.temporary_failure', # rubocop:disable Layout/LineLength
                                                       tags: ['service:supplemental-claims',
                                                              'function:form submission']).exactly(1).time
    end
  end

  context 'when the notification has some other status' do
    let(:other_notification) do
      OpenStruct.new(
        notification_id: SecureRandom.uuid,
        notification_type: 'email',
        source_location: 'unit-test',
        reference:,
        status: 'other',
        status_reason: 'unknown',
        callback_klass: described_class.to_s,
        callback_metadata: {
          email_type: :error,
          form_id: '995',
          submitted_appeal_uuid:,
          email_template_id: Settings.vanotify.services.benefits_decision_review.template_id.supplemental_claim_form_error_email, # rubocop:disable Layout/LineLength
          service_name: 'supplemental-claims'
        }
      )
    end

    it 'records an audit log for the other status' do
      expect(Rails.logger).to receive(:warn).with('DecisionReviews::FormNotificationCallback: Other',
                                                  anything)

      subject.call(other_notification)

      expect(DecisionReviewNotificationAuditLog).to have_received(:create!).with(
        notification_id: other_notification.notification_id,
        reference:,
        status: 'other',
        payload: other_notification.to_json
      )
    end
  end
end
