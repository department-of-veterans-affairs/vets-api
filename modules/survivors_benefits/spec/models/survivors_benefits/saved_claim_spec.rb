# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SurvivorsBenefits::SavedClaim do
  subject { described_class.new }

  let(:instance) { build(:survivors_benefits_claim) }

  it 'responds to #confirmation_number' do
    expect(subject.confirmation_number).to eq(subject.guid)
  end

  it 'has necessary constants' do
    expect(described_class).to have_constant(:FORM)
  end

  it 'descends from saved_claim' do
    expect(described_class.ancestors).to include(SavedClaim)
  end

  describe '#email' do
    it 'returns the users email' do
      expect(instance.email).to eq('test@example.com')
    end
  end

  describe '#business_line' do
    it 'returns the correct business line' do
      expect(subject.business_line).to eq('NCA')
    end
  end

  describe '#veteran_first_name' do
    it 'returns the first name of the veteran from parsed_form' do
      allow(instance).to receive(:parsed_form).and_return({ 'veteranFullName' => { 'first' => 'John' } })
      expect(instance.veteran_first_name).to eq('John')
    end

    it 'returns nil if the key does not exist' do
      allow(instance).to receive(:parsed_form).and_return({})
      expect(instance.veteran_first_name).to be_nil
    end
  end

  describe '#veteran_last_name' do
    it 'returns the last name of the veteran from parsed_form' do
      allow(instance).to receive(:parsed_form).and_return({ 'veteranFullName' => { 'last' => 'Doe' } })
      expect(instance.veteran_last_name).to eq('Doe')
    end

    it 'returns nil if the key does not exist' do
      allow(instance).to receive(:parsed_form).and_return({})
      expect(instance.veteran_last_name).to be_nil
    end
  end

  describe '#claimant_first_name' do
    it 'returns the first name of the claimant from parsed_form' do
      allow(instance).to receive(:parsed_form).and_return({ 'claimantFullName' => { 'first' => 'Derrick' } })
      expect(instance.claimant_first_name).to eq('Derrick')
    end

    it 'returns nil if the key does not exist' do
      allow(instance).to receive(:parsed_form).and_return({})
      expect(instance.claimant_first_name).to be_nil
    end
  end

  it 'inherits init callsbacks from saved_claim' do
    expect(subject.form_id).to eq(SurvivorsBenefits::FORM_ID)
    expect(subject.guid).not_to be_nil
    expect(subject.type).to eq(SurvivorsBenefits::SavedClaim.to_s)
  end

  describe '#process_attachments!' do
    it 'does NOT start a job to submit the saved claim via Benefits Intake' do
      expect(Lighthouse::SubmitBenefitsIntakeClaim).not_to receive(:perform_async)
      instance.process_attachments!
    end
  end

  describe '#to_pdf' do
    it 'calls PdfFill::Filler.fill_form' do
      expect(PdfFill::Filler).to receive(:fill_form).with(subject, nil, {})
      subject.to_pdf
    end

    [true, false].each do |extras_redesign|
      it "calls PdfFill::Filler.fill_form with extras_redesign: #{extras_redesign}" do
        expect(PdfFill::Filler).to receive(:fill_form).with(subject, nil, { extras_redesign: })
        subject.to_pdf(nil, { extras_redesign: })
      end
    end
  end

  describe '#send_email' do
    it 'calls SurvivorsBenefits::NotificationEmail with the claim id and delivers the email' do
      claim = build(:survivors_benefits_claim)
      email_type = :error
      notification_double = instance_double(SurvivorsBenefits::NotificationEmail)

      expect(SurvivorsBenefits::NotificationEmail).to receive(:new).with(claim.id).and_return(notification_double)
      expect(notification_double).to receive(:deliver).with(email_type)

      claim.send_email(email_type)
    end
  end
end
