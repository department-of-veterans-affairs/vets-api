# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Debts::Service do
  describe '#get_letters' do
    it 'should fetch the veterans debt letters data' do
      described_class.new.get_letters(fileNumber: '000000009')
    end
  end
end
