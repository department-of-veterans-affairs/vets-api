# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormDurations::CustomDuration do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of FormDurations::CustomDuration' do
      expect(subject.build(1)).to be_a(FormDurations::CustomDuration)
    end
  end

  describe '#duration' do
    context 'when positive' do
      let(:duration) { subject.build(90).span }

      it 'is an instance of ActiveSupport::Duration' do
        expect(duration).to be_a(ActiveSupport::Duration)
      end

      it 'returns 90 days' do
        expect(duration).to eq(90.days)
      end
    end

    context 'when zero' do
      let(:duration) { subject.build(0).span }

      it 'is an instance of ActiveSupport::Duration' do
        expect(duration).to be_a(ActiveSupport::Duration)
      end

      it 'returns 60 days' do
        expect(duration).to eq(60.days)
      end
    end
  end
end
