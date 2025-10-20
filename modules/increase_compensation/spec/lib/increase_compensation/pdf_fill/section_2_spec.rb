# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'
require 'increase_compensation/pdf_fill/va218940v1'
require 'fileutils'
require 'tmpdir'
require 'timecop'

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
