require 'rails_helper'
require 'mdot/v2/service'

describe MDOT::V2::Service do
  let(:user_details) do
    {
      first_name: 'patient',
      middle_name: nil,
      last_name: 'test',
      birth_date: '19220222',
      ssn: '000003322',
      icn: '82836359962678900'
    }
  end

  let(:user) { build(:user, :loa3, user_details) }

  around(:example) do |ex|
    VCR.configure do |c|
      c.hook_into :faraday
      # c.debug_logger = $stderr # or File.open('vcr.log', 'w')
    end

    options = {
      record: :none,
      record_on_error: false,
      allow_unused_http_interactions: false
    }.merge(VCR::MATCH_EVERYTHING)
    VCR.use_cassette(cassette, options) { ex.run }

    VCR.configure do |c|
      c.hook_into :webmock
      # c.debug_logger = nil
    end
  end

  describe "#authenticate" do
    let!(:cassette) { 'mdot/v2/20250414203819-get-supplies' }

    it "is successful" do
      MDOT::V2::Service.new(user).authenticate
    end
  end
end