require 'rails_helper'

describe Veteran do
  context 'initialization' do
    it 'should initialize from a hash' do
      veteran = Veteran.new social_security_number: "123456789"
      expect(veteran.social_security_number).to eq("123456789")
    end

    it 'should initialize from EVSS data' do
      evss_data = get_fixture('json/veteran_with_poa')
      veteran = Veteran.from_evss(evss_data)
      expect(veteran.veteran_name).to eq('JEFF TERRELL WATSON')
      expect(veteran.poa.code).to eq('A1Q')
    end
  end
end
