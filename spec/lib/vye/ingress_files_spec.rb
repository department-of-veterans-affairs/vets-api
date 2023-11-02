# frozen_string_literal: true

require 'rails_helper'
require 'vye/ingress_files'

RSpec.describe VYE::IngressFiles do
  describe '#bdn_feed_filename' do
    it 'returns a string' do
      expect(VYE::IngressFiles.bdn_feed_filename).to be_a(String)
    end
  end

  describe '#tims_feed_filename' do
    it 'returns a string' do
      expect(VYE::IngressFiles.tims_feed_filename).to be_a(String)
    end
  end
end
