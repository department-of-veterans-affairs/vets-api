# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::UserAcceptableVerifiedCredentialTotalsJob do
  shared_examples 'a StatsD gauge call' do |_params|
    it 'calls gauge with expected keys and counts' do
      allow(StatsD).to receive(:gauge)
      subject.perform

      expect(StatsD).to have_received(:gauge).with(expected_statsd_key, expected_statsd_count).exactly(1).time
    end
  end

  shared_context 'when there are avc' do
    let(:expected_scope) { :with_avc }
    it_behaves_like 'a StatsD gauge call'
  end

  shared_context 'when there are ivc' do
    let(:expected_scope) { :with_ivc }
    it_behaves_like 'a StatsD gauge call'
  end

  shared_context 'when there are no avc' do
    let(:expected_scope) { :without_avc }
    it_behaves_like 'a StatsD gauge call'
  end

  shared_context 'when there are no ivc' do
    let(:expected_scope) { :without_ivc }
    it_behaves_like 'a StatsD gauge call'
  end

  shared_context 'when there are no avc and ivc' do
    let(:expected_scope) { :without_avc_ivc }
    it_behaves_like 'a StatsD gauge call'
  end

  let!(:user_avcs) do
    create_list(:user_acceptable_verified_credential,
                expected_count,
                :"#{expected_provider}_verified_account",
                :"#{expected_scope}")
  end

  let(:expected_provider) { nil }
  let(:expected_scope) { nil }
  let(:expected_statsd_key) { "worker.user_avc_totals.#{expected_provider}.#{expected_scope}.total" }
  let(:expected_statsd_count) { expected_count }
  let(:expected_count) { UserAcceptableVerifiedCredential.all.count }

  describe '#perform' do
    subject { described_class.new }

    context 'idme verified accounts' do
      let(:expected_provider) { :idme }

      include_context 'when there are avc'
      include_context 'when there are ivc'
      include_context 'when there are no avc'
      include_context 'when there are no ivc'
      include_context 'when there are no avc and ivc'
    end

    context 'logingov verified accounts' do
      let(:expected_provider) { :logingov }

      include_context 'when there are avc'
      include_context 'when there are ivc'
      include_context 'when there are no avc'
      include_context 'when there are no ivc'
      include_context 'when there are no avc and ivc'
    end

    context 'dslogon verified accounts' do
      let(:expected_provider) { :dslogon }

      include_context 'when there are avc'
      include_context 'when there are ivc'
      include_context 'when there are no avc'
      include_context 'when there are no ivc'
      include_context 'when there are no avc and ivc'
    end

    context 'mhv verified accounts' do
      let(:expected_provider) { :mhv }

      include_context 'when there are avc'
      include_context 'when there are ivc'
      include_context 'when there are no avc'
      include_context 'when there are no ivc'
      include_context 'when there are no avc and ivc'
    end

    context 'combined mhv and dslogon accounts' do
      let(:expected_provider) { :mhv }

      let!(:dslogon_avcs) do
        create_list(:user_acceptable_verified_credential,
                    expected_count,
                    :dslogon_verified_account,
                    :"#{expected_scope}")
      end
      let(:expected_statsd_key) { "worker.user_avc_totals.mhv_dslogon.#{expected_scope}.total" }
      let(:expected_statsd_count) { UserAcceptableVerifiedCredential.all.count }

      include_context 'when there are avc'
      include_context 'when there are ivc'
      include_context 'when there are no avc'
      include_context 'when there are no ivc'
      include_context 'when there are no avc and ivc'
    end
  end
end
