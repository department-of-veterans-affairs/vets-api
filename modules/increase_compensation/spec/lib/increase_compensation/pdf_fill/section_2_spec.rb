# frozen_string_literal: true

require 'rails_helper'

describe IncreaseCompensation::PdfFill::Section2 do
  describe 'doctorsCareInLastYTD boolean field' do
    it 'get mapped correctly' do
      s2 = described_class.new
      data = { 'doctorsCareInLastYTD' => true }
      s2.expand(data)
      expect(data['doctorsCareInLastYTD']).to eq('YES')
      data['doctorsCareInLastYTD'] = false
      s2.expand(data)
      expect(data['doctorsCareInLastYTD']).to eq('NO')
      data['doctorsCareInLastYTD'] = ''
      s2.expand(data)
      expect(data['doctorsCareInLastYTD']).to eq('OFF')
    end
  end
end
