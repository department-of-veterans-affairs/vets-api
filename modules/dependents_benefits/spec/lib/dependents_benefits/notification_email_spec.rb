# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::NotificationEmail do
  let(:saved_claim) { create(:dependents_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(DependentsBenefits::SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:dependents_benefits).and_call_original

      args = [
        saved_claim.parsed_form.dig('dependents_application', 'veteran_contact_information', 'email_address'),
        Settings.vanotify.services['21_686c_674'].email.submitted.template_id,
        anything,
        Settings.vanotify.services['21_686c_674'].api_key,
        { callback_klass: DependentsBenefits::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:submitted)
    end
  end

  describe '#send_received_notification' do
    context 'when both 686c and 674 are submitted' do
      it 'sends the combined received notification email' do
        email_service = described_class.new(saved_claim.id)
        # rubocop:disable Naming/VariableNumber
        expect(email_service).to receive(:deliver).with(:received_686c_674)
        # rubocop:enable Naming/VariableNumber
        email_service.send_received_notification
      end
    end

    context 'when only 686c is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::SavedClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(DependentsBenefits::SavedClaim).to receive(:submittable_674?).and_return(false)
      end

      it 'sends the 686c only received notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:received_686c_only)
        email_service.send_received_notification
      end
    end

    context 'when only 674 is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::SavedClaim).to receive(:submittable_686?).and_return(false)
        allow_any_instance_of(DependentsBenefits::SavedClaim).to receive(:submittable_674?).and_return(true)
      end

      it 'sends the 674 only received notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:received_674_only)
        email_service.send_received_notification
      end
    end
  end

  describe '#send_error_notification' do
    context 'when both 686c and 674 are submitted' do
      it 'sends the combined error notification email' do
        email_service = described_class.new(saved_claim.id)
        # rubocop:disable Naming/VariableNumber
        expect(email_service).to receive(:deliver).with(:error_686c_674)
        # rubocop:enable Naming/VariableNumber
        email_service.send_error_notification
      end
    end

    context 'when only 686c is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::SavedClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(DependentsBenefits::SavedClaim).to receive(:submittable_674?).and_return(false)
      end

      it 'sends the 686c only error notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:error_686c_only)
        email_service.send_error_notification
      end
    end

    context 'when only 674 is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::SavedClaim).to receive(:submittable_686?).and_return(false)
        allow_any_instance_of(DependentsBenefits::SavedClaim).to receive(:submittable_674?).and_return(true)
      end

      it 'sends the 674 only error notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:error_674_only)
        email_service.send_error_notification
      end
    end
  end
end
