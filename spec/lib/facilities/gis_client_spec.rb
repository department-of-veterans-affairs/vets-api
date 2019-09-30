# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::GisClient do
  RSpec::Matchers.define :has_order_and_offset do |order, offset|
    match do |params|
      params[:orderByFields].eql?(order) && params[:resultOffset].eql?(offset)
    end
  end

  let(:faraday_response_offset_0) { double(Faraday::Response.new) }
  let(:faraday_response_offset_10) { double(Faraday::Response.new) }
  let(:faraday_response_offset_20) { double(Faraday::Response.new) }

  describe 'get_all_facilities' do
    subject { described_class.new }

    before(:each) do
      allow_any_instance_of(
        Faraday::Connection
      ).to receive(:get).with(anything, has_order_and_offset('field', 0)).and_return(faraday_response_offset_0)

      allow_any_instance_of(
        Faraday::Connection
      ).to receive(:get).with(anything, has_order_and_offset('field', 10)).and_return(faraday_response_offset_10)

      allow_any_instance_of(
        Faraday::Connection
      ).to receive(:get).with(anything, has_order_and_offset('field', 20)).and_return(faraday_response_offset_20)
    end

    it 'passes the correct offset to the query when looping twice' do
      allow(faraday_response_offset_0).to receive(:env).and_return(double(body: [*1..10]))
      allow(faraday_response_offset_10).to receive(:env).and_return(double(body: [*1..4]))

      data = subject.get_all_facilities('type', 'field', 10)
      expect(data.length).to be(14)
    end

    it 'passes the correct offset to the query when looping three times' do
      allow(faraday_response_offset_0).to receive(:env).and_return(double(body: [*1..10]))
      allow(faraday_response_offset_10).to receive(:env).and_return(double(body: [*1..10]))
      allow(faraday_response_offset_20).to receive(:env).and_return(double(body: []))

      data = subject.get_all_facilities('type', 'field', 10)
      expect(data.length).to be(20)
    end

    it 'passes the correct offset to the query when it does not loop' do
      allow(faraday_response_offset_0).to receive(:env).and_return(double(body: [*1..5]))

      data = subject.get_all_facilities('type', 'field', 10)
      expect(data.length).to be(5)
    end
  end
end
