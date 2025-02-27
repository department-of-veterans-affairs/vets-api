# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification, type: :model do
  let(:power_of_attorney_request) { create(:power_of_attorney_request) }
  let(:va_notify_notification) { create(:notification) }

  describe 'validations' do
    it {
      expect(subject).to validate_inclusion_of(:notification_type).in_array(%w[requested_poa declined_poa expiring_poa
                                                                               expired_poa])
    }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:power_of_attorney_request).class_name('PowerOfAttorneyRequest') }

    it {
      expect(subject).to belong_to(:va_notify_notification).class_name('VANotify::Notification').with_foreign_key('notification_id').with_primary_key('notification_id').optional
    }
  end

  describe 'scopes' do
    let!(:requested_poa_notification) do
      create(:power_of_attorney_request_notification, notification_type: 'requested_poa')
    end
    let!(:declined_poa_notification) do
      create(:power_of_attorney_request_notification, notification_type: 'declined_poa')
    end
    let!(:expiring_poa_notification) do
      create(:power_of_attorney_request_notification, notification_type: 'expiring_poa')
    end
    let!(:expired_poa_notification) do
      create(:power_of_attorney_request_notification, notification_type: 'expired_poa')
    end

    it 'returns requested_poa notifications' do
      expect(described_class.requested_poa).to include(requested_poa_notification)
      expect(described_class.requested_poa).not_to include(declined_poa_notification, expiring_poa_notification,
                                                           expired_poa_notification)
    end

    it 'returns declined_poa notifications' do
      expect(described_class.declined_poa).to include(declined_poa_notification)
      expect(described_class.declined_poa).not_to include(requested_poa_notification, expiring_poa_notification,
                                                          expired_poa_notification)
    end

    it 'returns expiring_poa notifications' do
      expect(described_class.expiring_poa).to include(expiring_poa_notification)
      expect(described_class.expiring_poa).not_to include(requested_poa_notification, declined_poa_notification,
                                                          expired_poa_notification)
    end

    it 'returns expired_poa notifications' do
      expect(described_class.expired_poa).to include(expired_poa_notification)
      expect(described_class.expired_poa).not_to include(requested_poa_notification, declined_poa_notification,
                                                         expiring_poa_notification)
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
end
