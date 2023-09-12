# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::Decliner, type: :service do
  describe '#perform!' do
    subject { decliner.perform! }

    let(:user_account) { create(:user_account) }
    let(:version) { 'v1' }
    let(:decliner) { described_class.new(user_account:, version:) }

    before do
      allow(TermsOfUse::SignUpServiceUpdaterJob).to receive(:perform_async)
    end

    it 'creates a new terms of use agreement with the given version' do
      expect { subject }.to change { user_account.terms_of_use_agreements.count }.by(1)
      expect(user_account.terms_of_use_agreements.last.agreement_version).to eq(version)
    end

    it 'marks the terms of use agreement as declined' do
      expect(subject).to be_declined
    end

    it 'enqueues the SignUpServiceUpdaterJob with the terms of use agreement id' do
      expect(TermsOfUse::SignUpServiceUpdaterJob).to have_received(:perform_async).with(subject.id)
    end
  end
end
