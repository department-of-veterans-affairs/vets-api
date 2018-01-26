# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSPolicy do
  context 'with a user who has the required evss attributes' do
    let(:user) { build(:user, :loa3) }
    let(:policy) { Pundit.policy(user, :evss) }

    it '#access? should return true' do
      expect(policy.access?).to be_truthy
    end
  end

  context 'with a user who does not have the required evss attributes' do
    let(:user) { build(:user, :loa1) }
    let(:policy) { Pundit.policy(user, :evss) }

    it '#access? should return false' do
      expect(policy.access?).to be_falsey
    end
  end
end
