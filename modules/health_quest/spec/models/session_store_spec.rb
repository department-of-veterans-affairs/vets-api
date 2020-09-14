# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/models/health_quest/session_store'

describe HealthQuest::SessionStore do
  subject { klass.new(uuid: 'e66fd7b7-94e0-4748-8063-283f55efb0ea', email: 'foo@bar.com') }

  let(:klass) do
    Class.new(Common::RedisStore) do
      redis_store 'my_namespace'
      redis_ttl 60
      redis_key :uuid

      attribute :uuid
      attribute :email
    end
  end

  describe '#update' do
    it 'updates the user attributes passed in as arguments' do
      subject.update(email: 'foo@barred.com')
      expect(subject.attributes).to eq(
        uuid: 'e66fd7b7-94e0-4748-8063-283f55efb0ea',
        email: 'foo@barred.com'
      )
    end
  end
end
