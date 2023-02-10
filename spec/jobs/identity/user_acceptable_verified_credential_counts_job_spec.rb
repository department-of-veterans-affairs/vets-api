# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::UserAcceptableVerifiedCredentialCountsJob do
  let(:idme_user_verification) { create(:idme_user_verification) }
  let(:logingov_user_verification) { create(:logingov_user_verification) }
  let(:dslogon_user_verification) { create(:dslogon_user_verification) }
  let(:mhv_user_verification) { create(:mhv_user_verification) }

  let!(:uavc_idme_account) do
    create(:user_acceptable_verified_credential, user_account: idme_user_verification.user_account,
                                                 acceptable_verified_credential_at: avc_timestamp1,
                                                 idme_verified_credential_at: ivc_timestamp1,
                                                 created_at: 1.day.ago)
  end
  let!(:uavc_logingov_account) do
    create(:user_acceptable_verified_credential, user_account: logingov_user_verification.user_account,
                                                 acceptable_verified_credential_at: avc_timestamp2,
                                                 idme_verified_credential_at: ivc_timestamp2,
                                                 created_at: 1.day.ago)
  end
  let!(:uavc_dslogon_account) do
    create(:user_acceptable_verified_credential, user_account: dslogon_user_verification.user_account,
                                                 acceptable_verified_credential_at: avc_timestamp3,
                                                 idme_verified_credential_at: ivc_timestamp3,
                                                 created_at: 1.day.ago)
  end
  let!(:uavc_mhv_account) do
    create(:user_acceptable_verified_credential, user_account: mhv_user_verification.user_account,
                                                 acceptable_verified_credential_at: avc_timestamp4,
                                                 idme_verified_credential_at: ivc_timestamp4,
                                                 created_at: 1.day.ago)
  end

  let(:avc_timestamp1) { all_avc_timestamp }
  let(:avc_timestamp2) { all_avc_timestamp }
  let(:avc_timestamp3) { all_avc_timestamp }
  let(:avc_timestamp4) { all_avc_timestamp }
  let(:all_avc_timestamp) { nil }

  let(:ivc_timestamp1) { all_ivc_timestamp }
  let(:ivc_timestamp2) { all_ivc_timestamp }
  let(:ivc_timestamp3) { all_ivc_timestamp }
  let(:ivc_timestamp4) { all_ivc_timestamp }
  let(:all_ivc_timestamp) { nil }

  describe '#perform' do
    subject { described_class.new }

    context 'when there are no avc and no ivc' do
      it 'sets data to expected counts' do
        expected_hash =
          {
            avc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            no_avc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            no_ivc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            no_avc_and_no_ivc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            timestamp: Time.zone.yesterday.as_json
          }

        expect(Rails.logger).to receive(:info).with('[UserAcceptableVerifiedCredentialCountsJob] - Ran', expected_hash)
        subject.perform
      end
    end

    context 'when there are avc but no ivc' do
      let(:all_avc_timestamp) { 1.day.ago }

      it 'sets data to expected counts' do
        expected_hash =
          {
            avc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            no_avc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            no_ivc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            no_avc_and_no_ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            timestamp: Time.zone.yesterday.as_json
          }
        expect(Rails.logger).to receive(:info).with('[UserAcceptableVerifiedCredentialCountsJob] - Ran', expected_hash)
        subject.perform
      end
    end

    context 'when there are ivc but no avc' do
      let(:all_ivc_timestamp) { 1.day.ago }

      it 'sets data to expected counts' do
        expected_hash =
          {
            avc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            ivc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            no_avc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            no_ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            no_avc_and_no_ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            timestamp: Time.zone.yesterday.as_json
          }
        expect(Rails.logger).to receive(:info).with('[UserAcceptableVerifiedCredentialCountsJob] - Ran', expected_hash)
        subject.perform
      end
    end

    context 'when there are both ivc and avc' do
      let(:all_ivc_timestamp) { 1.day.ago }
      let(:all_avc_timestamp) { 1.day.ago }

      it 'sets data to expected counts' do
        expected_hash =
          {
            avc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            ivc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            no_avc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            no_ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            no_avc_and_no_ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            timestamp: Time.zone.yesterday.as_json
          }
        expect(Rails.logger).to receive(:info).with('[UserAcceptableVerifiedCredentialCountsJob] - Ran', expected_hash)
        subject.perform
      end
    end

    context 'when there 2 ivc and 2 avc' do
      let(:ivc_timestamp1) { 1.day.ago }
      let(:ivc_timestamp2) { 1.day.ago }
      let(:avc_timestamp3) { 1.day.ago }
      let(:avc_timestamp4) { 1.day.ago }

      it 'sets data to expected counts' do
        expected_hash =
          {
            avc:
              {
                all: { added: 2, total: 2 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            ivc:
              {
                all: { added: 2, total: 2 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            no_avc:
              {
                all: { added: 2, total: 2 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            no_ivc:
              {
                all: { added: 2, total: 2 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            no_avc_and_no_ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            timestamp: Time.zone.yesterday.as_json
          }
        expect(Rails.logger).to receive(:info).with('[UserAcceptableVerifiedCredentialCountsJob] - Ran', expected_hash)
        subject.perform
      end
    end

    context 'when there are multiple of the same type of UserVerification record' do
      let(:all_ivc_timestamp) { 1.day.ago }
      let!(:idme_user_verification2) do
        create(:idme_user_verification, user_account: idme_user_verification.user_account)
      end

      it 'will count count distinct UserAcceptableVerifiedCredentail' do
        expected_hash =
          {
            avc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            ivc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            no_avc:
              {
                all: { added: 4, total: 4 },
                idme: { added: 1,  total: 1 },
                logingov: { added: 1, total: 1 },
                dslogon: { added: 1, total: 1 },
                mhv: { added: 1,  total: 1 }
              },
            no_ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            no_avc_and_no_ivc:
              {
                all: { added: 0, total: 0 },
                idme: { added: 0,  total: 0 },
                logingov: { added: 0, total: 0 },
                dslogon: { added: 0, total: 0 },
                mhv: { added: 0,  total: 0 }
              },
            timestamp: Time.zone.yesterday.as_json
          }
        expect(Rails.logger).to receive(:info).with('[UserAcceptableVerifiedCredentialCountsJob] - Ran', expected_hash)
        subject.perform
      end
    end
  end
end
