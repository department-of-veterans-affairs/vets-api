# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::DrivetimeBandClient do
  RSpec::Matchers.define :has_offset_and_limit do |offset, limit|
    match do |params|
      params[:resultRecordCount].eql?(limit) && params[:resultOffset].eql?(offset)
    end
  end

  let(:faraday_response_offset_0) { double(Faraday::Response.new) }
  let(:faraday_response_offset_10) { double(Faraday::Response.new) }

  describe 'get_drivetime_bands' do
    subject { described_class.new }

    before(:each) do
      allow_any_instance_of(
        Faraday::Connection
      ).to receive(:get).with(anything, has_offset_and_limit(0, 10)).and_return(faraday_response_offset_0)

      allow_any_instance_of(
        Faraday::Connection
      ).to receive(:get).with(anything, has_offset_and_limit(10, 10)).and_return(faraday_response_offset_10)
    end

    it 'uses offset and limit' do
      allow(faraday_response_offset_0).to receive(:env).and_return(double(body: { features: [*1..10] }.to_json))
      allow(faraday_response_offset_10).to receive(:env).and_return(double(body: { features: [*1..4] }.to_json))

      first_response = subject.get_drivetime_bands(0, 10)
      expect(first_response.length).to be(10)

      second_response = subject.get_drivetime_bands(10, 10)
      expect(second_response.length).to be(4)
    end
  end
end
