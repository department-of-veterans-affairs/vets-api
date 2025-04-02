# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification, type: :model do
  let(:power_of_attorney_request) { create(:power_of_attorney_request) }
  let(:va_notify_notification) { create(:notification) }

  describe 'validations' do
    it {
      expect(subject).to validate_inclusion_of(:type).in_array(%w[requested declined expiring
                                                                  expired])
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

    it 'returns requested notifications' do
      expect(described_class.requested).to include(requested_notification)
      expect(described_class.requested).not_to include(declined_notification, expiring_notification,
                                                       expired_notification)
    end

    it 'returns declined notifications' do
      expect(described_class.declined).to include(declined_notification)
      expect(described_class.declined).not_to include(requested_notification, expiring_notification,
                                                      expired_notification)
    end

    it 'returns expiring notifications' do
      expect(described_class.expiring).to include(expiring_notification)
      expect(described_class.expiring).not_to include(requested_notification, declined_notification,
                                                      expired_notification)
    end

    it 'returns expired notifications' do
      expect(described_class.expired).to include(expired_notification)
      expect(described_class.expired).not_to include(requested_notification, declined_notification,
                                                     expiring_notification)
    end
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

      it 'returns nil' do
        expect(notification.template_id).to be_nil
      end
    end

    context 'when type is expired' do
      let(:type) { 'expired' }

      it 'returns nil' do
        expect(notification.template_id).to be_nil
      end
    end
  end
end
