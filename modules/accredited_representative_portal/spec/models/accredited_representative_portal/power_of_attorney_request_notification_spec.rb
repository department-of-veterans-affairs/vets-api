# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification, type: :model do
  let(:power_of_attorney_request) { create(:power_of_attorney_request) }
  let(:va_notify_notification) { create(:notification) }

  describe 'validations' do
    it {
      expected_enum_values = described_class::PERMITTED_TYPES.index_with { |v| v }

      expect(subject).to define_enum_for(:type)
        .with_values(expected_enum_values)
        .backed_by_column_of_type(:string)
    }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:power_of_attorney_request).class_name('PowerOfAttorneyRequest') }

    it {
      expect(subject)
        .to belong_to(:va_notify_notification)
        .class_name('VANotify::Notification')
        .with_foreign_key('notification_id')
        .with_primary_key('notification_id')
        .optional
    }
  end

  describe 'scopes' do
    let!(:requested_notification) do
      create(:power_of_attorney_request_notification, type: 'requested')
    end
    let!(:declined_notification) do
      create(:power_of_attorney_request_notification, type: 'declined')
    end
    let!(:expiring_notification) do
      create(:power_of_attorney_request_notification, type: 'expiring')
    end
    let!(:expired_notification) do
      create(:power_of_attorney_request_notification, type: 'expired')
    end
    let!(:enqueue_failed_for_claimant_notification) do
      create(:power_of_attorney_request_notification, type: 'enqueue_failed_for_claimant')
    end
    let!(:enqueue_failed_for_rep_notification) do
      create(:power_of_attorney_request_notification, type: 'enqueue_failed_for_representative')
    end
    let!(:submission_failed_for_claimant_notification) do
      create(:power_of_attorney_request_notification, type: 'submission_failed_for_claimant')
    end
    let!(:submission_failed_for_rep_notification) do
      create(:power_of_attorney_request_notification, type: 'submission_failed_for_representative')
    end

    # rubocop:disable RSpec/RepeatedDescription, RSpec/RepeatedExample
    it 'returns requested notifications' do
      expect(described_class.requested).to include(requested_notification)
      expect(described_class.requested).not_to include(declined_notification, expiring_notification,
                                                       expired_notification,
                                                       enqueue_failed_for_claimant_notification,
                                                       enqueue_failed_for_rep_notification,
                                                       submission_failed_for_claimant_notification,
                                                       submission_failed_for_rep_notification)
    end

    it 'returns declined notifications' do
      expect(described_class.declined).to include(declined_notification)
      expect(described_class.declined).not_to include(requested_notification, expiring_notification,
                                                      expired_notification,
                                                      enqueue_failed_for_claimant_notification,
                                                      enqueue_failed_for_rep_notification,
                                                      submission_failed_for_claimant_notification,
                                                      submission_failed_for_rep_notification)
    end

    it 'returns expiring notifications' do
      expect(described_class.expiring).to include(expiring_notification)
      expect(described_class.expiring).not_to include(requested_notification, declined_notification,
                                                      expired_notification,
                                                      enqueue_failed_for_claimant_notification,
                                                      enqueue_failed_for_rep_notification,
                                                      submission_failed_for_claimant_notification,
                                                      submission_failed_for_rep_notification)
    end

    it 'returns expired notifications' do
      expect(described_class.expired).to include(expired_notification)
      expect(described_class.expired).not_to include(requested_notification, declined_notification,
                                                     expiring_notification,
                                                     enqueue_failed_for_claimant_notification,
                                                     enqueue_failed_for_rep_notification,
                                                     submission_failed_for_claimant_notification,
                                                     submission_failed_for_rep_notification)
    end

    it 'returns "enqueue failed" notifications meant for claimant' do
      expect(described_class.enqueue_failed_for_claimant).to include(enqueue_failed_for_claimant_notification)
      expect(described_class.enqueue_failed_for_claimant)
        .not_to include(requested_notification, declined_notification,
                        expiring_notification, expired_notification,
                        enqueue_failed_for_rep_notification,
                        submission_failed_for_claimant_notification,
                        submission_failed_for_rep_notification)
    end

    it 'returns "enqueue failed" notifications meant for rep' do
      expect(described_class.enqueue_failed_for_representative).to include(enqueue_failed_for_rep_notification)
      expect(described_class.enqueue_failed_for_representative)
        .not_to include(requested_notification, declined_notification,
                        expiring_notification, expired_notification,
                        enqueue_failed_for_claimant_notification,
                        submission_failed_for_rep_notification,
                        submission_failed_for_rep_notification)
    end

    it 'returns "enqueue failed" notifications meant for claimant' do
      expect(described_class.enqueue_failed_for_claimant).to include(enqueue_failed_for_claimant_notification)
      expect(described_class.enqueue_failed_for_claimant)
        .not_to include(requested_notification, declined_notification,
                        expiring_notification, expired_notification,
                        enqueue_failed_for_rep_notification,
                        submission_failed_for_claimant_notification,
                        submission_failed_for_rep_notification)
    end

    it 'returns "enqueue failed" notifications meant for rep' do
      expect(described_class.enqueue_failed_for_representative).to include(enqueue_failed_for_rep_notification)
      expect(described_class.enqueue_failed_for_representative)
        .not_to include(requested_notification, declined_notification,
                        expiring_notification, expired_notification,
                        enqueue_failed_for_claimant_notification,
                        submission_failed_for_rep_notification,
                        submission_failed_for_rep_notification)
    end
    # rubocop:enable RSpec/RepeatedDescription, RSpec/RepeatedExample
<<<<<<< HEAD
=======
  end

  describe '#status' do
    context 'when va_notify_notification is present' do
      let(:notification) do
        create(:power_of_attorney_request_notification, va_notify_notification:)
      end

      it 'returns the status of the va_notify_notification' do
        expect(notification.status).to eq(va_notify_notification.status.to_s)
      end
    end

    context 'when va_notify_notification is not present' do
      let(:notification) { create(:power_of_attorney_request_notification, va_notify_notification: nil) }

      it 'returns an empty string' do
        expect(notification.status).to eq('')
      end
    end
>>>>>>> 0205634a28 (rubocop issues; add flipper flag)
  end

  describe '#template_id' do
    let(:notification) { create(:power_of_attorney_request_notification, type:) }

    context 'when type is requested' do
      let(:type) { 'requested' }

      it 'returns the template id for the requested type' do
        expect(notification.template_id).to eq(
          Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_submit_confirmation_email
        )
      end
    end

    context 'when type is declined' do
      let(:type) { 'declined' }

      it 'returns the template id for the declined type' do
        expect(notification.template_id).to eq(
          Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_submit_decline_email
        )
      end
    end

    context 'when type is expiring' do
      let(:type) { 'expiring' }

      it 'returns the template id for the expiring type' do
        expect(notification.template_id).to eq(
          Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_expiration_warning_email
        )
      end
    end

    context 'when type is expired' do
      let(:type) { 'expired' }

      it 'returns the template id for the expired type' do
        expect(notification.template_id).to eq(
          Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_expiration_confirmation_email
        )
      end
    end
  end
end
