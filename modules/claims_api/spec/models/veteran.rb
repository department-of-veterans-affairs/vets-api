# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Veteran, type: :model do
  describe 'attributes needed for MVI lookup' do
    let(:headers) do
      {
        'X-VA-SSN' => '123456789',
        'X-VA-First-Name' => 'MARK',
        'X-VA-Last-Name' => 'WEBB',
        'X-VA-Birth-Date' => '1928-01-01'
      }
    end

    before do
      @veteran = ClaimsApi::Veteran.new
      @veteran.loa = { current: 3, highest: 3 }
      @veteran.edipi = '1234567'
    end

    it 'should delagate loa_user to loa3?' do
      expect(@veteran.loa3_user).to be(true)
    end

    it 'should always be valid for now to meet MVI need' do
      expect(@veteran.valid?).to be(true)
    end

    it 'should alias dslogon_edipi to edipi for MVI' do
      expect(@veteran.dslogon_edipi).to be(@veteran.edipi)
    end

    it 'should set edipi not passed in headers' do
      headers['X-VA-EDIPI'] = '12345'
      veteran = ClaimsApi::Veteran.from_headers(headers)
      expect(veteran.edipi).to eq('12345')
    end

    it 'should not set edipi if not passed in headers' do
      veteran = ClaimsApi::Veteran.from_headers(headers)
      expect(veteran.edipi).to be(nil)
    end
  end
end
