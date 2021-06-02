# frozen_string_literal: true

require 'rails_helper'

describe RedisCaching do
  describe '#get_cached' do
    it 'returns nil when nil value was set' do
      Message.set_cached('test-nil-cache-key', nil)
      expect(Message.get_cached('test-nil-cache-key')).to be_nil
    end
  end
end
