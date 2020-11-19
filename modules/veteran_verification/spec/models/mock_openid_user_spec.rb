# frozen_string_literal: true

require 'rails_helper'
require 'okta/service'
require_relative '../../app/models/veteran_verification/mock_open_id_user'

RSpec.describe MockOpenidUser, type: :model do
  let(:some_ttl) { 86_400 }
  let(:loa_three) { { current: LOA::THREE, highest: LOA::THREE } }
  let(:identity) { OpenidUserIdentity.create(build(:user_identity_attrs)) }

  it 'reuses the uuid' do
    user = MockOpenidUser.build_from_identity(identity: identity, ttl: some_ttl)
    expect(user.uuid).to eq(identity.uuid)
  end

  it 'passes same validity checks as User' do
    user = MockOpenidUser.build_from_identity(identity: identity, ttl: some_ttl)
    expect(user).to be_valid
  end

  it 'veteran' do
    user = MockOpenidUser.build_from_identity(identity: identity, ttl: some_ttl)
    vet = user.veteran?
    expect(vet).to eq(true)
  end

  context 'for loa3 users' do
    let(:identity) { OpenidUserIdentity.create(build(:user_identity_attrs, :loa3)) }

    it 'passes same vailidity checks as User' do
      user = MockOpenidUser.build_from_identity(identity: identity, ttl: some_ttl)
      expect(user).to be_valid
    end
  end
end
