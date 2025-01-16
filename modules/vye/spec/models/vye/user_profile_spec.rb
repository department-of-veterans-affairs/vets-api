# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::UserProfile, type: :model do
  describe '::find_and_update_icn' do
    before do
      allow(StatsD).to receive(:increment)
    end

    context 'when the user is blank' do
      let(:user) { nil }

      it 'logs an error and returns nil' do
        expect(Rails.logger)
          .to receive(:error)
          .with(/no user/)
        expect(described_class.find_and_update_icn(user:)).to be_nil
      end
    end

    context 'when the user is not loa3' do
      let(:user) { create(:user) }

      it 'logs an error and returns nil' do
        expect(Rails.logger)
          .to receive(:error)
          .with(/is not LOA3/)
        expect(described_class.find_and_update_icn(user:)).to be_nil
      end
    end

    context "when the user's ssn is blank" do
      let!(:user) { create(:evss_user, :loa3) }

      before { allow(user).to receive(:ssn).and_return(nil) }

      it 'logs an error and returns nil' do
        expect(Rails.logger)
          .to receive(:error)
          .with(/does not have an SSN/)
        expect(described_class.find_and_update_icn(user:)).to be_nil
      end
    end

    context "when the user's icn is blank" do
      let!(:user) { create(:evss_user, :loa3) }

      before { allow(user).to receive(:icn).and_return(nil) }

      it 'logs an error and returns nil' do
        expect(Rails.logger)
          .to receive(:error)
          .with(/does not have an ICN/)
        expect(described_class.find_and_update_icn(user:)).to be_nil
      end
    end

    context 'when the user_profile is found by icn' do
      let!(:user) { create(:evss_user, :loa3) }
      let!(:active_user_info) { create(:vye_user_info) }
      let!(:user_profile) { create(:vye_user_profile, ssn: user.ssn, icn: user.icn, active_user_info:) }

      it 'finds the user info by icn' do
        expect(StatsD).to receive(:increment).with('vye.user_profile.active_user_info_hit')
        expect(StatsD).to receive(:increment).with('vye.user_profile.icn_hit')

        u = described_class.find_and_update_icn(user:)

        expect(u).to eq(user_profile)
      end
    end

    context "when the user_profile is found by icn but doesn't have a active user_info" do
      let!(:user) { create(:evss_user, :loa3) }
      let!(:user_profile) { create(:vye_user_profile, ssn: user.ssn, icn: user.icn) }

      it 'finds the user info by icn' do
        expect(StatsD).to receive(:increment).with('vye.user_profile.active_user_info_miss')
        expect(StatsD).to receive(:increment).with('vye.user_profile.icn_hit')

        u = described_class.find_and_update_icn(user:)

        expect(u).to be_nil
      end
    end

    context 'when the user_profile is not found by icn' do
      let!(:user) { create(:evss_user, :loa3) }

      it 'increments icn_miss stat' do
        expect(StatsD).to receive(:increment).with('vye.user_profile.icn_miss')

        described_class.find_and_update_icn(user:)
      end
    end

    context 'when the user_profile is found by ssn' do
      let!(:user) { create(:evss_user, :loa3) }
      let!(:active_user_info) { create(:vye_user_info) }
      let!(:user_profile) { create(:vye_user_profile, ssn: user.ssn, active_user_info:) }

      it 'finds the user info by ssn and updates icn' do
        expect(StatsD).to receive(:increment).with('vye.user_profile.active_user_info_hit')
        expect(StatsD).to receive(:increment).with('vye.user_profile.ssn_hit')

        u = described_class.find_and_update_icn(user:)

        expect(u).to eq(user_profile)
        expect(u.icn_in_database).to eq(user.icn)
      end
    end

    # user_profile.update!(icn: user.icn)

    context "when the user_profile is found by ssn but doesn't have a active user_info" do
      let!(:user) { create(:evss_user, :loa3) }
      let!(:user_profile) { create(:vye_user_profile, ssn: user.ssn) }

      it 'finds the user info by ssn and updates icn' do
        expect(StatsD).to receive(:increment).with('vye.user_profile.active_user_info_miss')
        expect(StatsD).to receive(:increment).with('vye.user_profile.ssn_hit')

        u = described_class.find_and_update_icn(user:)
        user_profile.reload

        expect(u).to be_nil
        expect(user_profile.icn_in_database).to eq(user.icn)
      end
    end

    context 'when the user_profile is not found by ssn' do
      let!(:user) { create(:evss_user, :loa3) }

      it 'increments ssn_miss stat and logs a warning' do
        expect(StatsD).to receive(:increment).with('vye.user_profile.ssn_miss')

        expect(Rails.logger)
          .to receive(:warn)
          .with(/could not find by ICN or SSN/)

        u = described_class.find_and_update_icn(user:)

        expect(u).to be_nil
      end
    end
  end

  describe '#confirm_active_user_info_present?' do
    let!(:user_info) { create(:vye_user_info) }
    let!(:user_profile) { user_info.user_profile }

    it 'returns true' do
      expect(user_profile.confirm_active_user_info_present?).to be(true)
    end
  end

  describe '#active_user_info' do
    let!(:user_info) { create(:vye_user_info) }
    let!(:user_profile) { user_info.user_profile }

    it 'loads the user info' do
      expect(user_profile.active_user_info).to eq(user_info)
    end
  end

  describe '::find_or_build' do
    let(:ssn_digest_db) { described_class.gen_digest 'ssn_digest_db' }
    let(:ssn_digest_req) { described_class.gen_digest 'ssn_digest_req' }
    let(:ssn_digest_x) { described_class.gen_digest 'ssn_digest_x' }
    let(:file_number_digest_db) { described_class.gen_digest 'file_number_digest_db' }
    let(:file_number_digest_req) { described_class.gen_digest 'file_number_digest_req' }
    let(:file_number_digest_x) { described_class.gen_digest 'file_number_digest_x' }

    context 'when requested ssn_digest and file_number_digest are blank' do
      let(:ssn_digest_blank) { nil }
      let(:file_number_digest_blank) { nil }

      it 'returns nil' do
        r =
          described_class.send(
            :find_or_build,
            ssn_digest: ssn_digest_blank,
            file_number_digest: file_number_digest_blank
          )
        expect(r).to be_nil
      end
    end

    context "when requested ssn_digest and file_number_digest doesn't exists" do
      it 'builds one' do
        r =
          described_class.send(
            :find_or_build,
            ssn_digest: ssn_digest_req,
            file_number_digest: file_number_digest_req
          )
        expect(r.new_record?).to be(true)
      end
    end

    context 'when requested ssn_digest exists with a different file_number_digest' do
      let!(:user_profile) do
        create(:vye_user_profile_fresh_import, ssn_digest: ssn_digest_req, file_number_digest: file_number_digest_db)
      end

      it 'returns the ssn_digest match' do
        r =
          described_class.send(
            :find_or_build,
            ssn_digest: ssn_digest_req,
            file_number_digest: file_number_digest_x
          )
        expect(r).to eq(user_profile)
      end
    end

    context 'when requested file_number_digest exists with a different ssn_digest' do
      let!(:user_profile) do
        create(:vye_user_profile_fresh_import, ssn_digest: ssn_digest_db, file_number_digest: file_number_digest_req)
      end

      it 'returns the file_number_digest match' do
        r =
          described_class.send(
            :find_or_build,
            ssn_digest: ssn_digest_x,
            file_number_digest: file_number_digest_req
          )
        expect(r).to eq(user_profile)
      end
    end
  end

  describe '::produce' do
    let(:ssn_clear_db) { 'ssn_clear_db' }
    let(:ssn_digest_db) { 'ssn_digest_db' }

    let(:ssn_clear_req) { 'ssn_clear_req' }
    let(:ssn_digest_req) { 'ssn_digest_req' }

    let(:ssn_clear_x) { 'ssn_digest_x' }
    let(:ssn_digest_x) { 'ssn_digest_x' }

    let(:file_number_clear_db) { 'file_number_digest_db' }
    let(:file_number_digest_db) { 'file_number_digest_db' }

    let(:file_number_clear_req) { 'file_number_digest_req' }
    let(:file_number_digest_req) { 'file_number_digest_req' }

    let(:file_number_clear_x) { 'file_number_digest_x' }
    let(:file_number_digest_x) { 'file_number_digest_x' }

    let(:icn_db) { 'icn_db' }
    let(:icn_req) { 'icn_req' }

    context 'when requested ssn and file_number are blank' do
      let(:ssn) { '' }
      let(:file_number) { '' }

      it 'returns nil' do
        expect(described_class.produce(ssn:, file_number:)).to be_nil
      end
    end

    context 'all relevant attributes match' do
      let!(:user_profile) do
        create(
          :vye_user_profile_fresh_import,
          ssn_digest: ssn_digest_req,
          file_number_digest: file_number_digest_req,
          icn: icn_req
        )
      end

      it 'returns the found record and report no conflict' do
        expect(described_class).to receive(:gen_digest).with(ssn_clear_req).and_return(ssn_digest_req)
        expect(described_class).to receive(:gen_digest).with(file_number_clear_req).and_return(file_number_digest_req)

        found = described_class.produce(ssn: ssn_clear_req, file_number: file_number_clear_req)

        expect(found).to eq(user_profile)
      end
    end

    context "ssn_digest don't match" do
      let!(:user_profile) do
        create(:vye_user_profile_fresh_import, ssn_digest: ssn_digest_db, file_number_digest: file_number_digest_req)
      end

      it 'updates with given value and report the conflict' do
        expect(described_class).to receive(:gen_digest).with(ssn_clear_req).and_return(ssn_digest_req)
        expect(described_class).to receive(:gen_digest).with(file_number_clear_req).and_return(file_number_digest_req)

        user_profile = described_class.produce(ssn: ssn_clear_req, file_number: file_number_clear_req)

        expect(user_profile.attributes['ssn_digest']).to eq(ssn_digest_req)
        expect(user_profile.attributes['file_number_digest']).to eq(file_number_digest_req)
      end
    end

    context "file_number_digest don't match" do
      let!(:user_profile) do
        create(:vye_user_profile_fresh_import, ssn_digest: ssn_digest_req, file_number_digest: file_number_digest_db)
      end

      it 'updates with given value and report the conflict' do
        expect(described_class).to receive(:gen_digest).with(ssn_clear_req).and_return(ssn_digest_req)
        expect(described_class).to receive(:gen_digest).with(file_number_clear_req).and_return(file_number_digest_req)

        user_profile = described_class.produce(ssn: ssn_clear_req, file_number: file_number_clear_req)

        expect(user_profile.attributes['ssn_digest']).to eq(ssn_digest_req)
        expect(user_profile.attributes['file_number_digest']).to eq(file_number_digest_req)
      end
    end

    context "icn don't match" do
      let!(:user_profile) do
        create(
          :vye_user_profile_fresh_import,
          ssn_digest: ssn_digest_req,
          file_number_digest: file_number_digest_req,
          icn: icn_db
        )
      end

      it 'updates with given value and report the conflict' do
        expect(described_class).to receive(:gen_digest).with(ssn_clear_req).and_return(ssn_digest_req)
        expect(described_class).to receive(:gen_digest).with(file_number_clear_req).and_return(file_number_digest_req)

        user_profile = described_class.produce(ssn: ssn_clear_req, file_number: file_number_clear_req, icn: icn_req)

        expect(user_profile.attributes['ssn_digest']).to eq(ssn_digest_req)
        expect(user_profile.attributes['file_number_digest']).to eq(file_number_digest_req)
        expect(user_profile.attributes['icn']).to eq(icn_req)
      end
    end
  end
end
