# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe Veteran::VsoReloader, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  subject { described_class }

  describe 'importer' do
    it 'should reload data from pulldown' do
      VCR.use_cassette('veteran/ogc_poa_data') do
        Veteran::VsoReloader.new.perform
        expect(Veteran::Service::Representative.count).to eq 22_186
        expect(Veteran::Service::Organization.count).to eq 91
      end
    end
  end
end
