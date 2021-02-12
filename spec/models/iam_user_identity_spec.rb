# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IAMUserIdentity, type: :model do
  let(:dslogon_attrs) { build(:dslogon_level2_introspection_payload) }
  let(:mhv_attrs) { build(:mhv_premium_introspection_payload) }

  context 'for a DSLogon user' do
    it 'returns LOA3 for a premium assurance level' do
      id = described_class.build_from_iam_profile(dslogon_attrs)
      expect(id.loa[:current]).to eq(3)
    end
  end

  context 'for an MHV user' do
    it 'returns LOA3 for a premium assurance level' do
      id = described_class.build_from_iam_profile(mhv_attrs)
      expect(id.loa[:current]).to eq(3)
    end
  end
end
