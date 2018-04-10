# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe Vet360Cache do
  let(:user) { build(:user, :loa3) }
  let(:vet360) { Vet360Cache.for_user(user) }

  before do
    allow(user).to receive(:vet360_id).and_return('123456')
  end

  describe '.new' do
    it 'creates an instance with user attributes' do
      expect(vet360.user).to eq(user)
    end
  end

  it 'blah' do
byebug
  end
end
