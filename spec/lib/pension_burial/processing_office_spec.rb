# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionBurial::ProcessingOffice do
  context '#for_zip' do
    it 'should return an office name for a zip' do
      expect(described_class.for_zip(90_210)).to eq('St. Paul')
    end

    it 'should default to an office when no zip is mapped' do
      expect(described_class.for_zip(99_999)).to eq('Milwaukee')
    end
  end

  context '#address_for' do
    it 'returns an address including a po box' do
      answer = described_class.address_for(90_210)
      expect(answer.size).to eq(3)
      expect(answer.first).to include('St. Paul')
      expect(answer.last).to match(/\d{5}-\d{4}/)
    end
  end
end
