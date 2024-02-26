# frozen_string_literal: true

require 'rails_helper'
require 'vye/batch_transfer/ingress_files'

RSpec.describe VYE::BatchTransfer::IngressFiles do
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
end
