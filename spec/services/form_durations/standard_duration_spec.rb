# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormDurations::StandardDuration do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of FormDurations::StandardDuration' do
      expect(subject.build).to be_a(FormDurations::StandardDuration)
    end
  end

  describe '#duration' do
    let(:duration) { subject.build.span }

    it 'is an instance of ActiveSupport::Duration' do
      expect(duration).to be_a(ActiveSupport::Duration)
    end

    it 'returns 60 days' do
      expect(duration).to eq(60.days)
    end
  end
end
