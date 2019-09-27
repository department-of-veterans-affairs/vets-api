# frozen_string_literal: true

require 'rails_helper'
RSpec.describe Facilities::GisClient do
  RSpec::Matchers.define :has_order_and_offset do |order, offset|
    match do |params|
      params[:orderByFields].eql?(order) && params[:resultOffset].eql?(offset)
    end
  end

  context 'params' do
    subject { described_class.new }

    it 'passes the correct offset to the query when looping twice' do
      r1 = double(body: [*1..12])
      r2 = double(body: [*1..2])

      expect(subject).to receive(:perform).with(:get, anything, has_order_and_offset('field', 0)).and_return(r1)
      expect(subject).to receive(:perform).with(:get, anything, has_order_and_offset('field', 10)).and_return(r2)

      data = subject.get_all_facilities('type', 'field', 10)
      expect(data.length).to be(14)
    end

    it 'passes the correct offset to the query when looping three times' do
      r1 = double(body: [*1..10])
      r2 = double(body: [*1..10])
      r3 = double(body: [])

      expect(subject).to receive(:perform).with(:get, anything, has_order_and_offset('field', 0)).and_return(r1)
      expect(subject).to receive(:perform).with(:get, anything, has_order_and_offset('field', 10)).and_return(r2)
      expect(subject).to receive(:perform).with(:get, anything, has_order_and_offset('field', 20)).and_return(r3)

      data = subject.get_all_facilities('type', 'field', 10)
      expect(data.length).to be(20)
    end

    it 'passes the correct offset to the query when it does not loop' do
      r1 = double(body: [*1..5])

      expect(subject).to receive(:perform).with(:get, anything, has_order_and_offset('field', 0)).and_return(r1)

      data = subject.get_all_facilities('type', 'field', 10)
      expect(data.length).to be(5)
    end
  end
end
