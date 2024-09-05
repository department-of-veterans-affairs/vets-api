# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Names do
  describe '.all' do
    context 'when POA codes are valid' do
      before do
        allow(described_class).to receive(:orgs_data).and_return([
                                                                   { poa: '80', name: 'Blinded Veterans Association' },
                                                                   { poa: '85', name: 'Fleet Reserve Association' }
                                                                 ])
      end

      it 'returns serialized POA codes correctly' do
        expect(described_class.all).to eq([
                                            { poa: '080', name: 'Blinded Veterans Association' },
                                            { poa: '085', name: 'Fleet Reserve Association' }
                                          ])
      end
    end

    context 'when encountering an invalid POA code' do
      let(:invalid_data) { [{ poa: 'invalid', name: 'Invalid Organization' }] }

      before do
        allow(described_class).to receive(:orgs_data).and_return(invalid_data)
      end

      it 'handles the invalid record gracefully' do
        expect(described_class.all).to be_empty
      end
    end
  end
end
