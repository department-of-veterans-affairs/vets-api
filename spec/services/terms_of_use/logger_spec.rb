# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::Logger do
  subject { described_class.new(terms_of_use_agreement:) }

  let(:terms_of_use_agreement) { create(:terms_of_use_agreement, response:) }
  let(:user_account) { terms_of_use_agreement.user_account }
  let(:response) { 'accepted' }
  let(:expected_log_message) { "[TermsOfUseAgreement] [#{response.capitalize}]" }
  let(:expected_log_context) do
    {
      terms_of_use_agreement_id: terms_of_use_agreement.id,
      user_account_uuid: user_account.id,
      icn: user_account.icn,
      agreement_version: terms_of_use_agreement.agreement_version,
      response: terms_of_use_agreement.response
    }
  end

  let(:expected_statsd_key) { "api.terms_of_use_agreements.#{response}" }
  let(:expected_statsd_tags) { ["version:#{terms_of_use_agreement.agreement_version}"] }

  before do
    allow(Rails.logger).to receive(:info)
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    context 'when the terms of use agreement is accepted' do
      it 'logs the terms of use agreement' do
        subject.perform

        expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_context)
      end

      it 'increments the terms of use agreement statsd' do
        subject.perform

        expect(StatsD).to have_received(:increment).with(expected_statsd_key, tags: expected_statsd_tags)
      end
    end

    context 'when the terms of use agreement is declined' do
      let(:response) { 'declined' }

      it 'logs the terms of use agreement' do
        subject.perform

        expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_context)
      end

      it 'increments the terms of use agreement statsd' do
        subject.perform

        expect(StatsD).to have_received(:increment).with(expected_statsd_key, tags: expected_statsd_tags)
      end
    end
  end
end
