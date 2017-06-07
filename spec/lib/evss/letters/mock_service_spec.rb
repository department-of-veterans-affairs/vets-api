# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::MockService do
  describe '.find_by_user' do
    let(:root) { Rails.root }
    before do
      allow(Rails.root).to receive(:join).and_return(root.join('config', 'evss', 'mock_letters_response.yml.example'))
    end
    it 'returns a hash of the hard coded response' do
      response = subject.letters_by_user(nil)
      expect(response.address.address_line1).to eq('2476 MAIN STREET')
      expect(response.letters.count).to eq(8)
      expect(response.letters.first.as_json).to eq('name' => 'Commissary Letter', 'letter_type' => 'commissary')
    end
  end
end
