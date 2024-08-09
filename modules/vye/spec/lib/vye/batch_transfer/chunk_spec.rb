# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::Chunk do
  it 'can be instantiated' do
    offset = 0
    block_size = 1000
    file = Pathname.new('test.txt')

    expect(described_class.new(offset:, block_size:, file:)).to be_a described_class
  end
end
