# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/partial_date_parser'

RSpec.describe ClaimsApi::PartialDateParser do
  describe '.to_fes' do
    it { expect(described_class.to_fes('2018')).to eq(year: 2018) }
    it { expect(described_class.to_fes('2018-05')).to eq(year: 2018, month: 5) }
    it { expect(described_class.to_fes('2018-05-22')).to eq(year: 2018, month: 5, day: 22) }
    it { expect(described_class.to_fes('05-2018')).to eq(year: 2018, month: 5) }
    it { expect(described_class.to_fes('05-22-2018')).to eq(year: 2018, month: 5, day: 22) }
    it { expect(described_class.to_fes('2018-13-40')).to be_nil }
    it { expect(described_class.to_fes('')).to be_nil }
  end
end
