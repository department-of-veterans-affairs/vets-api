# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VaForms::Form, type: :model do
  describe 'importer' do
    it 'loads the initial set of data' do
      VCR.use_cassette('va_forms/forms') do
        allow(VaForms::Form).to receive(:get_sha256) { SecureRandom.hex(12) }
        expect do
          VaForms::Form.refresh!
        end.to change(VaForms::Form, :count).by(25)
      end
    end

    it 'gets the sha256 when contents are a Tempfile' do
      VCR.use_cassette('va_forms/tempfile') do
        url = 'https://www.va.gov/vaforms/va/pdf/VA10192.pdf'
        sha256 = VaForms::Form.get_sha256(url)
        expect(sha256).to eq('5fe171299ece147e8b456961a38e17f1391026f26e9e170229317bc95d9827b7')
      end
    end

    it 'gets the sha256 when contents are a StringIO' do
      VCR.use_cassette('va_forms/stringio') do
        url = 'http://www.vba.va.gov/pubs/forms/26-8599.pdf'
        sha256 = VaForms::Form.get_sha256(url)
        expect(sha256).to eq('f99d16fb94859065855dd71e3b253571229b31d4d46ca08064054b15207598bc')
      end
    end
  end
end
