# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Burial do
  subject { described_class.new }

  let(:instance) { FactoryBot.build(:burial_claim) }
  let(:instance_v2) { FactoryBot.build(:burial_claim_v2) }

  it 'responds to #confirmation_number' do
    expect(subject.confirmation_number).to eq(subject.guid)
  end

  it 'has necessary constants' do
    expect(described_class).to have_constant(:FORM)
  end

  it 'descends from saved_claim' do
    expect(described_class.ancestors).to include(SavedClaim)
  end

  describe '#process_attachments!' do
    it 'does NOT start a job to submit the saved claim via Benefits Intake' do
      expect(Lighthouse::SubmitBenefitsIntakeClaim).not_to receive(:perform_async)
      instance.process_attachments!
    end
  end

  context 'a record is processed through v2' do
    before do
      Flipper.enable(:va_burial_v2)
    end

    let(:subject_v2) { described_class.new(formV2: true) }

    it 'inherits init callsbacks from saved_claim' do
      expect(subject_v2.form_id).to eq('21P-530V2')
      expect(subject_v2.guid).not_to be_nil
      expect(subject_v2.type).to eq(described_class.to_s)
    end

    context 'validates against the form schema' do
      before do
        expect(instance_v2.valid?).to be(true)
        expect(JSON::Validator).to receive(:fully_validate).once.and_call_original
      end

      # NOTE: We assume all forms have the privacyAgreementAccepted element. Obviously.
      it 'rejects forms with missing elements' do
        bad_form = instance_v2.parsed_form.deep_dup
        bad_form.delete('privacyAgreementAccepted')
        instance_v2.form = bad_form.to_json
        instance_v2.remove_instance_variable(:@parsed_form)
        expect(instance_v2.valid?).to be(false)
        expect(instance_v2.errors.full_messages.size).to eq(1)
        expect(instance_v2.errors.full_messages).to include(/privacyAgreementAccepted/)
      end
    end
  end

  describe '#email' do
    it 'returns the users email' do
      expect(instance.email).to eq('foo@foo.com')
    end
  end
end
