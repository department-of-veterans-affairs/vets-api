# frozen_string_literal: true

require 'rails_helper'
require_relative '../factories/health_quest_users'
require_relative '../../app/services/health_quest/jwt_wrapper'
require_relative '../../app/services/health_quest/configuration'

describe HealthQuest::JwtWrapper do
  let(:user) { build(:user, :health_quest, :accountable) }
  let(:subject) { described_class.new(user) }
  let(:mykey) { OpenSSL::PKey::RSA.new(2048) }

  describe '#service_name' do
    it 'has a token' do
      allow(File).to receive(:read).and_return(mykey)
      # rubocop:disable Layout/LineLength
      decoded_token = JWT.decode(subject.token, HealthQuest::Configuration.instance.rsa_key, true, { algorithm: 'RS512' })
      # rubocop:enable Layout/LineLength
      expect(decoded_token[0]['firstName']).to eq('Judy')
      expect(decoded_token[0]['lastName']).to eq('Morrison')
    end
  end
end
