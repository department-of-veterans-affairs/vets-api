# frozen_string_literal: true

shared_examples_for 'saved_claim_with_confirmation_number' do
  it_behaves_like 'saved_claim'

  it 'responds to #confirmation_number' do
    expect(subject.confirmation_number).to eq(subject.guid)
  end
end

shared_examples_for 'saved_claim' do
  it 'has necessary constants' do
    expect(described_class).to have_constant(:FORM)
  end

  it 'descends from saved_claim' do
    expect(described_class.ancestors).to include(SavedClaim)
  end

  describe '#process_attachments!' do
    it 'starts a job to submit the saved claim' do
      expect(CentralMail::SubmitSavedClaimJob).to receive(:perform_async).with(instance.id)

      instance.process_attachments!
    end
  end

  context 'a record' do
    it 'inherits init callsbacks from saved_claim' do
      expect(subject.form_id).to eq(described_class::FORM)
      expect(subject.guid).not_to be_nil
      expect(subject.type).to eq(described_class.to_s)
    end
  end
end
