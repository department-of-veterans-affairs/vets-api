# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::PayloadBuilder::SharedHelpers do
  subject(:helper) do
    Class.new do
      include AskVAApi::Inquiries::PayloadBuilder::SharedHelpers
    end.new
  end

  describe '#fetch_state_code' do
    it 'returns nil when state is blank' do
      expect(helper.fetch_state_code(nil)).to be_nil
      expect(helper.fetch_state_code('')).to be_nil
      expect(helper.fetch_state_code('   ')).to be_nil
    end

    it 'passes through two-letter codes (normalized to uppercase)' do
      expect(helper.fetch_state_code('ca')).to eq('CA')
      expect(helper.fetch_state_code('NY')).to eq('NY')
      expect(helper.fetch_state_code('  fl ')).to eq('FL')
    end

    it 'maps known FE labels that are missing from locations.yml to codes' do
      expect(helper.fetch_state_code('Armed Forces Americas (AA)')).to eq('AA')
      expect(helper.fetch_state_code('American Samoa')).to eq('AS')
    end

    context 'when mapping state names via I18n' do
      before do
        # Keep this test independent of the real locations.yml contents/location.
        allow(I18n).to receive(:t).with('ask_va_api.states').and_return(
          {
            'CA' => 'California',
            'DC' => 'District of Columbia'
          }
        )
      end

      it 'maps state names to two-letter codes using the I18n state list' do
        expect(helper.fetch_state_code('California')).to eq('CA')
        expect(helper.fetch_state_code('District of Columbia')).to eq('DC')
      end

      it 'returns nil for unknown state names' do
        expect(helper.fetch_state_code('Unknown State')).to be_nil
      end
    end
  end
end
