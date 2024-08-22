# frozen_string_literal: true

require 'rails_helper'
require 'preneeds/service'

describe Preneeds::Service do
  let(:subject) { described_class.new }
  let(:burial_form) { build(:burial_form) }

  describe 'get_cemeteries' do
    it 'gets a collection of cemeteries' do
      cemeteries = VCR.use_cassette('preneeds/cemeteries/gets_a_list_of_cemeteries') do
        subject.get_cemeteries
      end

      expect(cemeteries).to be_a(Common::Collection)
      expect(cemeteries.type).to eq(Preneeds::Cemetery)
    end
  end
end
