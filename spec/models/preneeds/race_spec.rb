# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::Race do
  subject { build(:race) }

  describe '#as_eoas' do
    it 'should return the right value' do
      expect(subject.as_eoas).to eq([{:raceCd=>"I"}, {:raceCd=>"U"}])
    end
  end
end
