# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Login::UserAcceptableVerifiedCredentialUpdaterLogger do
  shared_examples 'a logger' do
    it 'logs expected message and payload' do
      expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_payload)
      subject
    end
  end

  shared_examples 'a logingov or idme statsd increment' do
    it 'increments expected statsd keys' do
      subject
      expect(StatsD).to have_received(:increment).exactly(1).time
      expect(StatsD).to have_received(:increment).with(expected_single_statsd_key, 1).exactly(1).time
    end
  end

  shared_examples 'a mhv or dslogon statsd increment' do
    it 'increments expected statsd keys' do
      subject
      expect(StatsD).to have_received(:increment).exactly(2).time
      expect(StatsD).to have_received(:increment).with(expected_single_statsd_key, 1).exactly(1).time
      expect(StatsD).to have_received(:increment).with(expected_combined_statsd_key, 1).exactly(1).time
    end
  end

  describe '#perform' do
    subject do
      described_class.new(user_acceptable_verified_credential: user_avc).perform
    end

    let(:user_avc) { 'some-user_acceptable_verified_credential' }

    context 'when user_avc is nil' do
      let(:user_avc) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when user_avc is defined' do
      let(:user_avc) do
        create(:user_acceptable_verified_credential,
               user_account:,
               acceptable_verified_credential_at:,
               idme_verified_credential_at:)
      end
      let(:user_account) { create(:user_account) }
      let(:expected_verified_credential_at) { '2023-1-1' }
      let(:expected_log_message) { '[UserAcceptableVerifiedCredentialUpdater] - User AVC Updated' }
      let(:expected_log_payload) do
        payload = {}
        payload[:added_type] = expected_added_type
        payload[:added_from] = expected_added_from_type
        payload[:user_account_id] = user_account.id
        if expected_added_from_type == 'mhv'
          payload[:backing_idme_uuid] =
            user_account&.user_verifications&.mhv&.first&.backing_idme_uuid
          payload[:mhv_uuid] =
            user_account&.user_verifications&.mhv&.first&.mhv_uuid
        end
        if expected_added_from_type == 'dslogon'
          payload[:backing_idme_uuid] =
            user_account&.user_verifications&.dslogon&.first&.backing_idme_uuid
          payload[:dslogon_uuid] =
            user_account&.user_verifications&.dslogon&.first&.dslogon_uuid
        end
        payload[:idme_uuid] = user_account&.user_verifications&.idme&.first&.idme_uuid
        payload[:logingov_uuid] = user_account&.user_verifications&.logingov&.first&.logingov_uuid

        payload
      end

      let(:expected_single_statsd_key) do
        "api.user_avc_updater.#{expected_added_from_type}.#{expected_added_type}.added"
      end

      let(:expected_combined_statsd_key) do
        "api.user_avc_updater.mhv_dslogon.#{expected_added_type}.added"
      end

      before do
        Timecop.freeze(expected_verified_credential_at)
        allow(StatsD).to receive(:increment)
      end

      after { Timecop.return }

      context 'and there is a change to acceptable_verified_credential_at' do
        let(:acceptable_verified_credential_at) { expected_verified_credential_at }
        let!(:user_verification) { create(:logingov_user_verification, user_account:) }
        let(:expected_added_type) { 'avc' }

        context 'and idme_verified_credential_at is nil' do
          let(:idme_verified_credential_at) { nil }

          context 'and logingov is the only user_verification' do
            let(:expected_added_from_type) { 'logingov' }

            it_behaves_like 'a logger'
            it_behaves_like 'a logingov or idme statsd increment'
          end

          context 'and there is also a mhv verification' do
            let!(:mhv_verification) { create(:mhv_user_verification, user_account:) }
            let(:expected_added_from_type) { 'mhv' }

            it_behaves_like 'a logger'
            it_behaves_like 'a mhv or dslogon statsd increment'
          end

          context 'and there is also a dslogon verification' do
            let!(:dslogon_verification) { create(:dslogon_user_verification, user_account:) }
            let(:expected_added_from_type) { 'dslogon' }

            it_behaves_like 'a logger'
            it_behaves_like 'a mhv or dslogon statsd increment'
          end
        end

        context 'and there is already an idme_verified_credential_at' do
          let(:idme_verified_credential_at) { expected_verified_credential_at }
          let!(:idme_verification) { create(:idme_user_verification, user_account:) }
          let(:expected_added_from_type) { 'idme' }

          before do
            allow_any_instance_of(UserAcceptableVerifiedCredential)
              .to receive(:saved_change_to_idme_verified_credential_at?).and_return(false)
          end

          it_behaves_like 'a logger'
          it_behaves_like 'a logingov or idme statsd increment'
        end
      end

      context 'and there is a change to idme_verified_credential_at' do
        let(:idme_verified_credential_at) { expected_verified_credential_at }
        let!(:user_verification) { create(:idme_user_verification, user_account:) }
        let(:expected_added_type) { 'ivc' }

        context 'and acceptable_verified_credential_at is nil' do
          let(:acceptable_verified_credential_at) { nil }

          context 'when idme is the only user_verification' do
            let(:expected_added_from_type) { 'idme' }

            it_behaves_like 'a logger'
            it_behaves_like 'a logingov or idme statsd increment'
          end

          context 'and there is also a mhv verification' do
            let!(:mhv_verification) { create(:mhv_user_verification, user_account:) }
            let(:expected_added_from_type) { 'mhv' }

            it_behaves_like 'a logger'
            it_behaves_like 'a mhv or dslogon statsd increment'
          end

          context 'and there is also a dslogon verification' do
            let!(:dslogon_verification) { create(:dslogon_user_verification, user_account:) }
            let(:expected_added_from_type) { 'dslogon' }

            it_behaves_like 'a logger'
            it_behaves_like 'a mhv or dslogon statsd increment'
          end
        end

        context 'and there is already an acceptable_verified_credential_at' do
          let(:acceptable_verified_credential_at) { expected_verified_credential_at }
          let!(:logingov_verification) { create(:logingov_user_verification, user_account:) }
          let(:expected_added_from_type) { 'logingov' }

          before do
            allow_any_instance_of(UserAcceptableVerifiedCredential)
              .to receive(:saved_change_to_acceptable_verified_credential_at?).and_return(false)
          end

          it_behaves_like 'a logger'
          it_behaves_like 'a logingov or idme statsd increment'
        end
      end
    end
  end
end
