# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::MockService do
  describe '.find_by_user' do
    let(:root) { Rails.root }
    context 'when the yaml file exists' do
      before do
        allow(Rails.root).to receive(:join).and_return(root.join('config', 'evss', 'mock_letters_response.yml.example'))
      end
      it 'returns a hash of the hard coded response' do
        response = subject.get_letters
        expect(response.address.address_line1).to eq('2476 MAIN STREET')
        expect(response.letters.count).to eq(8)
        expect(response.letters.first.as_json).to eq('name' => 'Commissary Letter', 'letter_type' => 'commissary')
      end
    end

    context 'when the yaml file does not exist' do
      before do
        allow(Rails.root).to receive(:join).and_return(root.join('config', 'evss', 'foo.yml'))
      end
      it 'raises an IOError' do
        expect { subject.get_letters }.to raise_error(
          IOError, 'letters mock data not found in path: /Users/vhaisfdawsoa/Documents/va/vets-api/config/evss/foo.yml'
        )
      end
    end
  end
end
