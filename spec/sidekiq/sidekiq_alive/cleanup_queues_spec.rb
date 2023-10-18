# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SidekiqAlive::CleanupQueues do
  describe '#perform' do
    let(:subject) { described_class.new }

    it 'does not raise an error when the job succeeds' do
      expect do
        subject.perform
      end.not_to raise_error
    end
  end
end
