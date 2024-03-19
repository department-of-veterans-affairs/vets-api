# frozen_string_literal: true

require 'rails_helper'
require 'vye/batch_transfer/ingress_files'

RSpec.describe Vye::BatchTransfer::IngressFiles do
  describe '#bdn_feed_filename' do
    it 'returns a string' do
      expect(described_class.bdn_feed_filename).to be_a(String)
    end
  end

  describe '#tims_feed_filename' do
    it 'returns a string' do
      expect(described_class.tims_feed_filename).to be_a(String)
    end
  end

  it 'imports lines from BDN extract' do
    data = Vye::Engine.root / 'spec/fixtures/bdn_sample/WAVE.txt'
    expect do
      described_class.bdn_import(data)
    end.not_to raise_error
  end
end
