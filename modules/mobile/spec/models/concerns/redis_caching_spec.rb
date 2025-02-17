# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Concerns::RedisCaching do
  let(:user) { build(:user) }

  describe '#get_cached' do
    it 'returns nil when nil value was set' do
      Mobile::V0::ClaimOverview.set_cached(user, nil)
      expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
    end
  end
end
