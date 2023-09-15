# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::Acceptor, type: :service do
  describe '#perform!' do
    subject { acceptor.perform! }

    let(:user_account) { create(:user_account) }
    let(:version) { 'v1' }
    let(:common_name) { 'some-common-name' }
    let(:acceptor) { described_class.new(user_account:, common_name:, version:) }

    before do
      allow(TermsOfUse::SignUpServiceUpdaterJob).to receive(:perform_async)
    end

    it 'creates a new terms of use agreement with the given version' do
      expect { subject }.to change { user_account.terms_of_use_agreements.count }.by(1)
      expect(user_account.terms_of_use_agreements.last.agreement_version).to eq(version)
    end

    it 'marks the terms of use agreement as accepted' do
      expect(subject).to be_accepted
    end

    it 'enqueues the SignUpServiceUpdaterJob with the terms of use agreement id' do
      expect(TermsOfUse::SignUpServiceUpdaterJob).to have_received(:perform_async).with(subject.id, common_name)
    end
  end
end
