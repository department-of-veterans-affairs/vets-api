# frozen_string_literal: true

require 'rails_helper'
require 'vye/batch_transfer/ingress_files'

RSpec.describe VYE::BatchTransfer::IngressFiles do
  describe '#bdn_feed_filename' do
    it 'returns a string' do
      expect(VYE::BatchTransfer::IngressFiles.bdn_feed_filename).to be_a(String)
    end
  end

  describe '#tims_feed_filename' do
    it 'returns a string' do
      expect(VYE::BatchTransfer::IngressFiles.tims_feed_filename).to be_a(String)
    end
  end
end
