# frozen_string_literal: true

require 'pensions/pdf_fill/sections/section_11'

describe Pensions::PdfFill::Section11 do
  describe '#expand' do
    it 'sets correct account type' do
      form_data = { 'bankAccount' => { 'accountType' => 'checking' } }
      described_class.new.expand(form_data)
      expect(form_data['bankAccount']['accountType']).to eq(0)

      form_data = { 'bankAccount' => { 'accountType' => 'savings' } }
      described_class.new.expand(form_data)
      expect(form_data['bankAccount']['accountType']).to eq(1)

      form_data = { 'bankAccount' => nil }
      described_class.new.expand(form_data)
      expect(form_data['bankAccount']['accountType']).to eq(2)

      form_data = { 'bankAccount' => { 'accountType' => nil } }
      described_class.new.expand(form_data)
      expect(form_data['bankAccount']['accountType']).to be_nil
    end
  end
end
