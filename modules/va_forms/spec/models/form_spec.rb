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
  end
end
