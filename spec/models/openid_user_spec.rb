# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OpenidUser, type: :model do
  let(:some_ttl) { 86_400 }
  let(:loa_three) { { current: LOA::THREE, highest: LOA::THREE } }
  let(:identity) { OpenidUserIdentity.create(build(:user_identity_attrs)) }

  it 'should reuse the uuid' do
    user = OpenidUser.build_from_identity(identity: identity, ttl: some_ttl)
    expect(user.uuid).to eq(identity.uuid)
  end

  it 'should pass same validity checks as User' do
    user = OpenidUser.build_from_identity(identity: identity, ttl: some_ttl)
    expect(user).to be_valid
  end

  context 'for loa3 users' do
    let(:identity) { OpenidUserIdentity.create(build(:user_identity_attrs, :loa3)) }

    it 'should pass same vailidity checks as User' do
      user = OpenidUser.build_from_identity(identity: identity, ttl: some_ttl)
      expect(user).to be_valid
    end
  end
end
