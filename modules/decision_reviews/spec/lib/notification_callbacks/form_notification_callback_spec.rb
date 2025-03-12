# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require 'decision_reviews/notification_callbacks/form_notification_callback'

describe DecisionReviews::FormNotificationCallback do
  subject { described_class }

  let(:reference) { "SC-form-#{SecureRandom.uuid}" }
  let(:saved_claim_id) { SecureRandom.uuid }
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
        form_id: '995',
        saved_claim_id:,
        email_template_id: Settings.vanotify.services.benefits_decision_review.template_id.supplemental_claim_form_error_email, # rubocop:disable Layout/LineLength
        service_name: 'supplemental-claims'
      }
    )
  end

  before do
    allow(DecisionReviewNotificationAuditLog).to receive(:create!)
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
  end

  it 'records and logs a successful form delivery' do
    subject.call(delivered_notification)

    expect(DecisionReviewNotificationAuditLog).to have_received(:create!).with(
      notification_id: delivered_notification.notification_id, 
      reference:, 
      status: 'delivered', 
      payload: delivered_notification.to_json
      )

    expect(Rails.logger).to have_received(:error) do |message, payload|
      expect(message).to eq('Silent failure avoided')
      expect(payload[:service]).to eq('supplemental-claims')
      expect(payload[:function]).to eq('form submission')
      expect(payload[:additional_context][:callback_metadata][:form_id]).to eq('995')
      expect(payload[:additional_context][:callback_metadata][:saved_claim_id])
        .to eq(saved_claim_id)
    end
    expect(StatsD).to have_received(:increment).with('silent_failure_avoided',
                                                     tags: ['service:supplemental-claims',
                                                            'function:form submission']).exactly(1).time
  end
end
