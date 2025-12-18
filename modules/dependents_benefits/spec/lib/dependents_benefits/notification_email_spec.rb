# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/notification_callback'
require 'dependents_benefits/notification_email'

RSpec.describe DependentsBenefits::NotificationEmail do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
  end

  let(:saved_claim) { create(:dependents_claim) }
  let(:vanotify) { double(send_email: true) }

  describe '#deliver' do
    it 'successfully sends an email' do
      api_key = Settings.vanotify.services.dependents_benefits.api_key
      callback_options = { callback_klass: DependentsBenefits::NotificationCallback.to_s, callback_metadata: be_a(Hash) }

      expect(DependentsBenefits::PrimaryDependencyClaim).to receive(:find).at_least(:once).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:dependents_benefits).and_call_original
      expect(VaNotify::Service).to receive(:new).with(api_key, callback_options).and_return(vanotify)
      expect(vanotify).to receive(:send_email).with(
        {
          email_address: 'test@test.com',
          template_id: Settings.vanotify.services['21_686c_674'].email.submitted686c674.template_id,
          personalisation: {
            'first_name' => 'MARK',
            'date_submitted' => an_instance_of(String),
            'confirmation_number' => saved_claim.confirmation_number
          }
        }.compact
      )

      described_class.new(23).deliver(:submitted686c674)
    end
  end

  describe '#send_received_notification' do
    context 'when both 686c and 674 are submitted' do
      it 'sends the combined received notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:received_686c_674) # rubocop:disable Naming/VariableNumber
        email_service.send_received_notification
      end
    end

    context 'when only 686c is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(
          :submittable_674?
        ).and_return(false)
      end

      it 'sends the 686c only received notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:received_686c_only)
        email_service.send_received_notification
      end
    end

    context 'when only 674 is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(
          :submittable_686?
        ).and_return(false)
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(:submittable_674?).and_return(true)
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
        expect(email_service).to receive(:deliver).with(:error_686c_674) # rubocop:disable Naming/VariableNumber
        email_service.send_error_notification
      end
    end

    context 'when only 686c is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(
          :submittable_674?
        ).and_return(false)
      end

      it 'sends the 686c only error notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:error_686c_only)
        email_service.send_error_notification
      end
    end

    context 'when only 674 is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(
          :submittable_686?
        ).and_return(false)
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(:submittable_674?).and_return(true)
      end

      it 'sends the 674 only error notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:error_674_only)
        email_service.send_error_notification
      end
    end
  end

  describe '#send_submitted_notification' do
    context 'when both 686c and 674 are submitted' do
      it 'sends the combined submitted notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:submitted686c674)
        email_service.send_submitted_notification
      end
    end

    context 'when only 686c is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(
          :submittable_674?
        ).and_return(false)
      end

      it 'sends the 686c only submitted notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:submitted686c_only)
        email_service.send_submitted_notification
      end
    end

    context 'when only 674 is submitted' do
      before do
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(
          :submittable_686?
        ).and_return(false)
        allow_any_instance_of(DependentsBenefits::PrimaryDependencyClaim).to receive(:submittable_674?).and_return(true)
      end

      it 'sends the 674 only submitted notification email' do
        email_service = described_class.new(saved_claim.id)
        expect(email_service).to receive(:deliver).with(:submitted674_only)
        email_service.send_submitted_notification
      end
    end
  end
end
