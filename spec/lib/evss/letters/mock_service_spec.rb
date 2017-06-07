# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::MockService do
  describe '.find_by_user' do
    let(:mock_response) { YAML.load_file(Rails.root.join('config', 'evss', 'mock_letters_response.yml.example')) }
    before { allow_any_instance_of(EVSS::Letters::MockService).to receive(:mocked_response).and_return(mock_response) }
    it 'returns a hash of the hard coded response' do
      response = subject.letters_by_user(nil)
      expect(response.address.address_line1).to eq('2476 MAIN STREET')
      expect(response.letters.count).to eq(8)
      expect(response.letters.first.as_json).to eq('name' => 'Commissary Letter', 'letter_type' => 'commissary')
    end
  end
end
