# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Burials::SavedClaim do
  subject { described_class.new }

  let(:instance) { build(:burials_saved_claim) }

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
    it 'inherits init callsbacks from saved_claim' do
      expect(subject.form_id).to eq('21P-530EZ')
      expect(subject.guid).not_to be_nil
      expect(subject.type).to eq(SavedClaim::Burial.to_s)
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

  describe '#benefits_claimed' do
    it 'returns a full array of values' do
      benefits_claimed = instance.benefits_claimed
      expected = ['Burial Allowance', 'Plot Allowance', 'Transportation']

      expect(benefits_claimed.length).to eq(3)
      expect(benefits_claimed).to eq(expected)
    end

    it 'returns at least an empty array' do
      form = instance.parsed_form

      form = form.merge({ 'transportation' => false })
      claim = build(:burials_saved_claim, form: form.to_json)
      benefits_claimed = claim.benefits_claimed
      expected = ['Burial Allowance', 'Plot Allowance']
      expect(benefits_claimed.length).to eq(2)
      expect(benefits_claimed).to eq(expected)

      form = form.merge({ 'plotAllowance' => false })
      claim = build(:burials_saved_claim, form: form.to_json)
      benefits_claimed = claim.benefits_claimed
      expected = ['Burial Allowance']
      expect(benefits_claimed.length).to eq(1)
      expect(benefits_claimed).to eq(expected)

      form = form.merge({ 'burialAllowance' => false })
      claim = build(:burials_saved_claim, form: form.to_json)
      benefits_claimed = claim.benefits_claimed
      expected = []
      expect(benefits_claimed.length).to eq(0)
      expect(benefits_claimed).to eq(expected)
    end
  end

  describe '#business_line' do
    it 'returns the correct business line' do
      expect(subject.business_line).to eq('NCA')
    end
  end

  describe '#veteran_first_name' do
    it 'returns the first name of the veteran from parsed_form' do
      allow(instance).to receive(:parsed_form).and_return({ 'veteranFullName' => { 'first' => 'WESLEY' } })
      expect(instance.veteran_first_name).to eq('WESLEY')
    end

    it 'returns nil if the key does not exist' do
      allow(instance).to receive(:parsed_form).and_return({})
      expect(instance.veteran_first_name).to be_nil
    end
  end

  describe '#veteran_last_name' do
    it 'returns the last name of the veteran from parsed_form' do
      allow(instance).to receive(:parsed_form).and_return({ 'veteranFullName' => { 'last' => 'FORD' } })
      expect(instance.veteran_last_name).to eq('FORD')
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

  context 'after create' do
    it 'tracks pdf overflow' do
      allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(true)
      allow(StatsD).to receive(:increment)
      instance.save!

      expect(StatsD).to have_received(:increment).with('saved_claim.pdf.overflow', tags: ['form_id:21P-530EZ'])
    end
  end
end
