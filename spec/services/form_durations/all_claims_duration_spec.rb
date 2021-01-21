# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormDurations::AllClaimsDuration do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of FormDurations::AllClaimsDuration' do
      expect(subject.build).to be_a(FormDurations::AllClaimsDuration)
    end
  end

  describe '#duration' do
    let(:duration) { subject.build.span }

    it 'is an instance of ActiveSupport::Duration' do
      expect(duration).to be_a(ActiveSupport::Duration)
    end

    it 'returns 1 year' do
      expect(duration).to eq(1.year)
    end
  end
end
