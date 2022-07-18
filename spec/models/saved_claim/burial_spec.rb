# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Burial do
  subject { described_class.new }

  let(:instance) { FactoryBot.build(:burial_claim) }

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
    it 'starts a job to submit the saved claim' do
      expect_any_instance_of(CentralMail::SubmitSavedClaimJob).to receive(:perform).with(instance.id)

      instance.process_attachments!
    end
  end

  context 'a record' do
    it 'inherits init callsbacks from saved_claim' do
      expect(subject.form_id).to eq(described_class::FORM)
      expect(subject.guid).not_to be_nil
      expect(subject.type).to eq(described_class.to_s)
    end

    context 'validates against the form schema' do
      before do
        expect(instance.valid?).to be(true)
        expect(JSON::Validator).to receive(:fully_validate).once.and_call_original
      end

      # NOTE: We assume all forms have the privacyAgreementAccepted element. Obviously.
      it 'rejects forms with missing elements' do
        bad_form = instance.parsed_form.deep_dup
        bad_form.delete('privacyAgreementAccepted')
        instance.form = bad_form.to_json
        instance.remove_instance_variable(:@parsed_form)
        expect(instance.valid?).to be(false)
        expect(instance.errors.full_messages.size).to eq(1)
        expect(instance.errors.full_messages).to include(/privacyAgreementAccepted/)
      end
    end
  end

  describe '#email' do
    it 'returns the users email' do
      expect(instance.email).to eq('foo@foo.com')
    end
  end
end
