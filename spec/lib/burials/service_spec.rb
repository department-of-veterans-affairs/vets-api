# frozen_string_literal: true
require 'rails_helper'
require 'burials/service'

describe Burials::Service do
  let(:subject) { described_class.new }

  describe 'cemeteries' do
    it 'gets a collection of cemeteries' do
      cemeteries = VCR.use_cassette('burials/cemeteries/gets_a_list_of_cemeteries') do
        subject.get_cemeteries
      end

      expect(cemeteries).to be_a(Common::Collection)
      expect(cemeteries.type).to eq(Cemetery)
    end
  end
end
