# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncreaseCompensation::ZsfConfig do
  subject { described_class.new }

  describe '#s3_settings' do
    it 'returns s3 setting form config files' do
      expect(subject.s3_settings).to eq(Settings.bio.increase_compensation)
    end
  end
end
