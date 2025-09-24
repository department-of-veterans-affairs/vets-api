# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IAMUserIdentity, type: :model do
  let(:idme_attrs) { build(:idme_loa3_introspection_payload) }
  let(:dslogon_attrs) { build(:dslogon_level2_introspection_payload) }
  let(:mhv_attrs) { build(:mhv_premium_introspection_payload) }
  let(:logingov_attrs) { build(:logingov_ial2_introspection_payload) }

  context 'for a Login.gov user' do
    it 'returns IAL2 for a premium assurance level' do
      id = described_class.build_from_iam_profile(logingov_attrs)
      expect(id.loa[:current]).to eq(3)
    end

    it 'returns multifactor as true' do # all login.gov users are forced to use MFA
      id = described_class.build_from_iam_profile(logingov_attrs)
      expect(id.multifactor).to be(true)
    end
  end

  context 'for an ID.me user' do
    it 'returns LOA3 for a premium assurance level' do
      id = described_class.build_from_iam_profile(idme_attrs)
      expect(id.loa[:current]).to eq(3)
    end

    it 'returns multifactor as true' do
      id = described_class.build_from_iam_profile(idme_attrs)
      expect(id.multifactor).to be(true)
    end
  end

  context 'for a DSLogon user' do
    it 'returns LOA3 for a premium assurance level' do
      id = described_class.build_from_iam_profile(dslogon_attrs)
      expect(id.loa[:current]).to eq(3)
    end

    it 'returns multifactor as false' do
      id = described_class.build_from_iam_profile(dslogon_attrs)
      expect(id.multifactor).to be(false)
    end
  end

  context 'for an MHV user' do
    it 'returns LOA3 for a premium assurance level' do
      id = described_class.build_from_iam_profile(mhv_attrs)
      expect(id.loa[:current]).to eq(3)
    end

    it 'returns multifactor as false' do
      id = described_class.build_from_iam_profile(mhv_attrs)
      expect(id.multifactor).to be(false)
    end
  end

  context 'with multiple MHV IDs' do
    it 'plucks the first value' do
      attrs = mhv_attrs.merge(fediam_mhv_ien: '123456,7890123')
      id = described_class.build_from_iam_profile(attrs)
      expect(id.iam_mhv_id).to eq('123456')
    end

    it 'logs a warning to Rails logger' do
      attrs = mhv_attrs.merge(fediam_mhv_ien: '123456,7890123')
      expect(Rails.logger).to receive(:warn).with(
        '[IAMUserIdentity] OAuth: Multiple MHV IDs present',
        mhv_ien: '123456,7890123'
      )
      described_class.build_from_iam_profile(attrs)
    end

    it 'ignores non-unique duplicates' do
      attrs = mhv_attrs.merge(fediam_mhv_ien: '123456,123456')
      expect(Sentry).not_to receive(:capture_message)
      id = described_class.build_from_iam_profile(attrs)
      expect(id.iam_mhv_id).to eq('123456')
    end
  end

  context 'with no MHV ID' do
    it 'parses reserved value correctly' do
      attrs = mhv_attrs.merge(fediam_mhv_ien: 'NOT_FOUND')
      id = described_class.build_from_iam_profile(attrs)
      expect(id.iam_mhv_id).to be_nil
    end
  end

  context 'with a user who has a found EDIPI' do
    it 'returns edipi number' do
      id = described_class.build_from_iam_profile(idme_attrs)
      expect(id.iam_edipi).to eq('1005079124')
    end
  end

  context 'with a user who has a not found EDIPI' do
    it 'returns nil' do
      id = described_class.build_from_iam_profile(mhv_attrs)
      expect(id.iam_edipi).to be_nil
    end
  end
end
