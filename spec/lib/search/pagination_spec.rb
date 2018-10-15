# frozen_string_literal: true

require 'rails_helper'

describe Search::Pagination do
  [nil, 20, 40, 60, 80].each do |next_offset|
    context "when next_offset is #{next_offset}" do
      let(:raw_body) do
        {
          'total' => 84,
          'next_offset' => next_offset
        }
      end
      subject { described_class.new(raw_body) }

      it 'calculates the correct previous offset' do
        prev_offset = case next_offset
                      when 20 # Cursor on first page
                        nil
                      when 40 # Cursor on second page
                        nil
                      when 60 # Cursor on third page
                        20
                      when 80 # Cursor on fourth page
                        40
                      when nil # Cursor on last page
                        60 # Expect to be (total - (remainder + (2 * OFFSET_LIMIT)))
                      end
        expect(subject.object).to include('previous' => prev_offset)
        expect(subject.object).to include('next' => next_offset)
      end
    end
  end
end
