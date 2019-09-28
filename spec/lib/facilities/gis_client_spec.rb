# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::GisClient do
  RSpec::Matchers.define :has_order_and_offset do |order, offset|
    match do |params|
      params[:orderByFields].eql?(order) && params[:resultOffset].eql?(offset)
    end
  end

  describe 'get_all_facilities' do
    subject { described_class.new }

    it 'passes the correct offset to the query when looping twice' do
      r1 = double(Faraday::Response.new)
      r2 = double(Faraday::Response.new)

      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything, has_order_and_offset('field', 0))
                                                                 .and_return(r1)
      expect(r1).to receive(:env).and_return(double(body: [*1..12]))

      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything, has_order_and_offset('field', 10))
                                                                 .and_return(r2)
      expect(r2).to receive(:env).and_return(double(body: [*1..2]))

      data = subject.get_all_facilities('type', 'field', 10)
      expect(data.length).to be(14)
    end

    it 'passes the correct offset to the query when looping three times' do
      r1 = double(Faraday::Response.new)
      r2 = double(Faraday::Response.new)
      r3 = double(Faraday::Response.new)

      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything, has_order_and_offset('field', 0))
                                                                 .and_return(r1)
      expect(r1).to receive(:env).and_return(double(body: [*1..10]))

      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything, has_order_and_offset('field', 10))
                                                                 .and_return(r2)
      expect(r2).to receive(:env).and_return(double(body: [*1..10]))

      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything, has_order_and_offset('field', 20))
                                                                 .and_return(r3)
      expect(r3).to receive(:env).and_return(double(body: []))

      data = subject.get_all_facilities('type', 'field', 10)
      expect(data.length).to be(20)
    end

    it 'passes the correct offset to the query when it does not loop' do
      r1 = double(Faraday::Response.new)

      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything, has_order_and_offset('field', 0))
                                                                 .and_return(r1)
      expect(r1).to receive(:env).and_return(double(body: [*1..5]))

      data = subject.get_all_facilities('type', 'field', 10)
      expect(data.length).to be(5)
    end
  end
end
