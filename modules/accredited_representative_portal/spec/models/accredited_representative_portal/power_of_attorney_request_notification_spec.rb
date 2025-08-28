# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification, type: :model do
  let(:power_of_attorney_request) { create(:power_of_attorney_request) }
  let(:va_notify_notification) { create(:notification) }

  describe 'validations' do
    it do
      expected_enum_values = described_class::PERMITTED_TYPES.index_with { |v| v }

      expect(subject)
        .to define_enum_for(:type)
        .with_values(expected_enum_values)
        .backed_by_column_of_type(:string)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:power_of_attorney_request).class_name('PowerOfAttorneyRequest') }

    it do
      expect(subject)
        .to belong_to(:va_notify_notification)
        .class_name('VANotify::Notification')
        .with_foreign_key('notification_id')
        .with_primary_key('notification_id')
        .optional
    end
  end

  describe '#status' do
    context 'when va_notify_notification is present' do
      let(:notification) { create(:power_of_attorney_request_notification, va_notify_notification:) }

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
    let(:recipient_type) { 'claimant' }
    let(:notification) do
      create(
        :power_of_attorney_request_notification,
        type:,
        recipient_type:,
        power_of_attorney_request:
      )
    end

    context 'when type is requested' do
      let(:type) { 'requested' }

      it 'returns the confirmation template id' do
        expect(notification.template_id).to eq(
          Settings
            .vanotify
            .services
            .va_gov
            .template_id
            .appoint_a_representative_digital_submit_confirmation_email
        )
      end
    end

    context 'when type is declined' do
      let(:type) { 'declined' }

      it 'returns the decline template id' do
        expect(notification.template_id).to eq(
          Settings
            .vanotify
            .services
            .va_gov
            .template_id
            .appoint_a_representative_digital_submit_decline_email
        )
      end
    end

    context 'when type is expiring' do
      let(:type) { 'expiring' }

      it 'returns the expiration warning template id' do
        expect(notification.template_id).to eq(
          Settings
            .vanotify
            .services
            .va_gov
            .template_id
            .appoint_a_representative_digital_expiration_warning_email
        )
      end
    end

    context 'when type is expired' do
      let(:type) { 'expired' }

      it 'returns the expiration confirmation template id' do
        expect(notification.template_id).to eq(
          Settings
            .vanotify
            .services
            .va_gov
            .template_id
            .appoint_a_representative_digital_expiration_confirmation_email
        )
      end
    end

    context 'when type is enqueue_failed' do
      let(:type) { 'enqueue_failed' }

      it 'returns claimant failure template for claimant recipient' do
        expect(notification.template_id).to eq(
          Settings
            .vanotify
            .services
            .va_gov
            .template_id
            .accredited_representative_portal_poa_request_failure_claimant_email
        )
      end

      context 'with resolver recipient' do
        let(:recipient_type) { 'resolver' }

        it 'returns resolver failure template' do
          expect(notification.template_id).to eq(
            Settings
              .vanotify
              .services
              .va_gov
              .template_id
              .accredited_representative_portal_poa_request_failure_rep_email
          )
        end
      end

      context 'with representative recipient' do
        let(:recipient_type) { 'representative' }

        it 'logs a warning and returns nil' do
          expect(Rails.logger).to receive(:warn).with(/Missing template/)
          expect(notification.template_id).to be_nil
        end
      end
    end

    context 'when type is unknown' do
      let(:notification) do
        build(
          :power_of_attorney_request_notification,
          type: 'requested',
          recipient_type: 'claimant'
        )
      end

      it 'logs a warning and returns nil' do
        allow(notification).to receive(:type).and_return('bogus')

        expect(Rails.logger).to receive(:warn).with(/Unknown notification type=bogus/)
        expect(notification.template_id).to be_nil
      end
    end
  end

  describe '#claimant_hash' do
    let(:request) { create(:power_of_attorney_request) }
    let(:notification) do
      build(:power_of_attorney_request_notification, power_of_attorney_request: request)
    end

    it 'returns dependent if present' do
      form = request.power_of_attorney_form || create(:power_of_attorney_form, power_of_attorney_request: request)
      allow(request).to receive(:power_of_attorney_form).and_return(form)
      allow(form).to receive(:parsed_data).and_return({ 'dependent' => { 'email' => 'dep@example.com' } })

      expect(notification.claimant_hash['email']).to eq('dep@example.com')
    end

    it 'falls back to veteran if dependent is missing' do
      form = request.power_of_attorney_form || create(:power_of_attorney_form, power_of_attorney_request: request)
      allow(request).to receive(:power_of_attorney_form).and_return(form)
      allow(form).to receive(:parsed_data).and_return({ 'veteran' => { 'email' => 'vet@example.com' } })

      expect(notification.claimant_hash['email']).to eq('vet@example.com')
    end
  end

  describe '#email_address' do
    let(:notification) do
      build(:power_of_attorney_request_notification, recipient_type:, power_of_attorney_request:)
    end

    context 'when recipient_type is representative' do
      let(:recipient_type) { 'representative' }

      it 'returns accredited individual email' do
        allow(notification).to receive(:representative_email_address).and_return('rep@example.com')
        expect(notification.email_address).to eq('rep@example.com')
      end
    end

    context 'when recipient_type is resolver' do
      let(:recipient_type) { 'resolver' }

      it 'returns resolver email' do
        allow(notification).to receive(:resolver_email_address).and_return('resolver@example.com')
        expect(notification.email_address).to eq('resolver@example.com')
      end
    end

    context 'when recipient_type is claimant' do
      let(:recipient_type) { 'claimant' }

      it 'returns claimant hash email' do
        allow(notification).to receive(:claimant_hash).and_return({ 'email' => 'claimant@example.com' })
        expect(notification.email_address).to eq('claimant@example.com')
      end
    end
  end

  describe '#representative_email_address' do
    let(:notification) { build(:power_of_attorney_request_notification, power_of_attorney_request:) }

    it 'returns accredited individual email if present' do
      individual = double('AccreditedIndividual', email: 'ind@example.com')
      allow(notification).to receive(:accredited_individual).and_return(individual)
      expect(notification.representative_email_address).to eq('ind@example.com')
    end

    it 'returns nil if no accredited individual' do
      allow(notification).to receive(:accredited_individual).and_return(nil)
      expect(notification.representative_email_address).to be_nil
    end
  end

  describe '#resolver_email_address' do
    let(:notification) { build(:power_of_attorney_request_notification, power_of_attorney_request:) }

    it 'returns resolver email if present' do
      resolver_individual = double('AccreditedIndividual', email: 'resolver@example.com')
      resolution = double('Resolution', resolving: double(accredited_individual: resolver_individual))
      allow(notification.power_of_attorney_request).to receive(:resolution).and_return(resolution)

      expect(notification.resolver_email_address).to eq('resolver@example.com')
    end

    it 'returns nil if no resolution' do
      allow(notification.power_of_attorney_request).to receive(:resolution).and_return(nil)
      expect(notification.resolver_email_address).to be_nil
    end
  end
end
