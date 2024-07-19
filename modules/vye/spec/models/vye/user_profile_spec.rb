# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::UserProfile, type: :model do
  describe 'find_by_user after ICN is recorded' do
    let!(:user) { create(:evss_user, :loa3) }
    let!(:user_profile) { described_class.create(ssn: user.ssn, file_number: user.ssn, icn: user.icn) }

    it 'finds the user info by icn' do
      u = described_class.find_and_update_icn(user:)
      expect(u).to eq(user_profile)
    end
  end

  describe 'find_by_user before ICN is recorded' do
    let!(:user) { create(:evss_user, :loa3) }
    let!(:user_profile) { described_class.create(ssn: user.ssn, file_number: user.ssn) }

    it 'finds the user info by ssn' do
      u = described_class.find_and_update_icn(user:)

      expect(u).to eq(user_profile)

      expect(u.ssn_digest_in_database.length).to be(16)
      expect(u.ssn_digest.length).to be(36)

      expect(u.icn_in_database).to eq(user.icn)
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

  describe '#check_for_match' do
    let!(:user_profile) do
      create(:vye_user_profile_fresh_import)
    end

    it 'reports if nothings changed' do
      ssn_digest, = user_profile.attributes.values_at('ssn_digest')
      user_profile.assign_attributes(ssn_digest:)

      conflict, attribute_name = user_profile.check_for_match.values_at(:conflict, :attribute_name)
      expect(conflict).to be(false)
      expect(attribute_name).to be_nil
    end

    it 'reports if ssn_digest has changed' do
      user_profile.assign_attributes(ssn_digest: 'ssn_digest_x')

      conflict, attribute_name = user_profile.check_for_match.values_at(:conflict, :attribute_name)
      expect(conflict).to be(true)
      expect(attribute_name).to eq('ssn_digest')
    end

    it 'reports if file_number_digest has changed' do
      user_profile.assign_attributes(file_number_digest: 'file_number_digest_x')

      conflict, attribute_name = user_profile.check_for_match.values_at(:conflict, :attribute_name)
      expect(conflict).to be(true)
      expect(attribute_name).to eq('file_number_digest')
    end

    it 'reports if icn is changed' do
      user_profile.assign_attributes(icn: 'icn_x')

      conflict, attribute_name = user_profile.check_for_match.values_at(:conflict, :attribute_name)
      expect(conflict).to be(true)
      expect(attribute_name).to eq('icn')
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

        found, conflict, attribute_name =
          described_class
          .produce(ssn: ssn_clear_req, file_number: file_number_clear_req)
          .values_at(:user_profile, :conflict, :attribute_name)

        expect(found).to eq(user_profile)
        expect(conflict).to be(false)
        expect(attribute_name).to be_nil
      end
    end

    context "ssn_digest don't match" do
      let!(:user_profile) do
        create(:vye_user_profile_fresh_import, ssn_digest: ssn_digest_db, file_number_digest: file_number_digest_req)
      end

      it 'updates with given value and report the conflict' do
        expect(described_class).to receive(:gen_digest).with(ssn_clear_req).and_return(ssn_digest_req)
        expect(described_class).to receive(:gen_digest).with(file_number_clear_req).and_return(file_number_digest_req)

        user_profile, conflict, attribute_name =
          described_class
          .produce(ssn: ssn_clear_req, file_number: file_number_clear_req)
          .values_at(:user_profile, :conflict, :attribute_name)

        expect(user_profile.attributes['ssn_digest']).to eq(ssn_digest_req)
        expect(user_profile.attributes['file_number_digest']).to eq(file_number_digest_req)
        expect(conflict).to be(true)
        expect(attribute_name).to eq('ssn_digest')
      end
    end

    context "file_number_digest don't match" do
      let!(:user_profile) do
        create(:vye_user_profile_fresh_import, ssn_digest: ssn_digest_req, file_number_digest: file_number_digest_db)
      end

      it 'updates with given value and report the conflict' do
        expect(described_class).to receive(:gen_digest).with(ssn_clear_req).and_return(ssn_digest_req)
        expect(described_class).to receive(:gen_digest).with(file_number_clear_req).and_return(file_number_digest_req)

        user_profile, conflict, attribute_name =
          described_class
          .produce(ssn: ssn_clear_req, file_number: file_number_clear_req)
          .values_at(:user_profile, :conflict, :attribute_name)

        expect(user_profile.attributes['ssn_digest']).to eq(ssn_digest_req)
        expect(user_profile.attributes['file_number_digest']).to eq(file_number_digest_req)
        expect(conflict).to be(true)
        expect(attribute_name).to eq('file_number_digest')
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

        user_profile, conflict, attribute_name =
          described_class
          .produce(ssn: ssn_clear_req, file_number: file_number_clear_req, icn: icn_req)
          .values_at(:user_profile, :conflict, :attribute_name)

        expect(user_profile.attributes['ssn_digest']).to eq(ssn_digest_req)
        expect(user_profile.attributes['file_number_digest']).to eq(file_number_digest_req)
        expect(user_profile.attributes['icn']).to eq(icn_req)
        expect(conflict).to be(true)
        expect(attribute_name).to eq('icn')
      end
    end
  end
end
