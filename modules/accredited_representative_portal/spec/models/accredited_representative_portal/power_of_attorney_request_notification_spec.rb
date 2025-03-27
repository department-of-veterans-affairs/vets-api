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

  describe '#personalisation' do
    let(:notification) { create(:power_of_attorney_request_notification, type:) }

    context 'when type is declined' do
      let(:type) { 'declined' }

      it 'returns a hash with the first name' do
        expect(notification.personalisation).to eq('first_name' => notification.first_name)
      end
    end

    context 'when type is expiring' do
      let(:type) { 'expiring' }

      it 'returns a hash with the first name' do
        expect(notification.personalisation).to eq('first_name' => notification.first_name)
      end
    end

    context 'when type is expired' do
      let(:type) { 'expired' }

      it 'returns a hash with the first name' do
        expect(notification.personalisation).to eq('first_name' => notification.first_name)
      end
    end

    context 'when type is requested' do
      let(:type) { 'requested' }

      it 'returns the full hash for the digital submit confirmation email' do
        expected_hash = {
          'first_name' => notification.first_name,
          'last_name' => notification.last_name,
          'submit_date' => notification.submit_date,
          'expiration_date' => notification.expiration_date,
          'representative_name' => notification.representative_name
        }
        expect(notification.personalisation).to eq(expected_hash)
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

  describe 'dates' do
    let(:notification) { create(:power_of_attorney_request_notification) }

    it 'returns the submit date' do
      time_zone = 'Eastern Time (US & Canada)'
      expect(notification.submit_date).to eq(Time.zone.now.in_time_zone(time_zone).strftime('%B %d, %Y'))
    end

    it 'returns the expiration date' do
      matching_time = Time.zone.now.in_time_zone('Eastern Time (US & Canada)') + 60.days
      expect(notification.expiration_date).to eq(matching_time.strftime('%B %d, %Y'))
    end
  end

  describe '#representative_name' do
    let(:representative) { create(:representative, first_name: 'Rep', last_name: 'Name') }
    let(:organization) { create(:organization, name: 'Org Name') }

    context 'when accredited_individual and accredited_organization are present' do
      it 'returns the full name of the individual and the name of the organization' do
        poa_request = create(:power_of_attorney_request,
                             accredited_individual_registration_number: representative.representative_id)
        poa_request.power_of_attorney_holder_poa_code = organization.poa
        notification = create(:power_of_attorney_request_notification, power_of_attorney_request: poa_request)
        expect(notification.representative_name).to eq(
          "#{notification.accredited_individual.full_name.strip} accredited with #{notification.accredited_organization.name.strip}"
        )
      end
    end

    context 'when accredited_individual is present' do
      it 'returns the full name of the individual' do
        poa_request = create(:power_of_attorney_request,
                             accredited_individual_registration_number: representative.representative_id)
        notification = create(:power_of_attorney_request_notification,
                              power_of_attorney_request: poa_request)
        expect(notification.representative_name).to eq(notification.accredited_individual.full_name.strip)
      end
    end

    context 'when accredited_organization is present' do
      it 'returns the name of the organization' do
        expect(notification.representative_name).to eq(notification.accredited_organization.name.strip)
      end
    end
  end
end
