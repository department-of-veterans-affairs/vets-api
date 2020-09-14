# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::ExtendSessionJob do
  let(:subject) { described_class.new }

  before do
    allow_any_instance_of(HealthQuest::UserService).to receive(:update_session_token).and_return('stubbed_token')
  end

  describe '#perform' do
    it 'gets a token' do
      expect(subject.perform('dummy_uid')).to eq 'stubbed_token'
    end
  end
end
