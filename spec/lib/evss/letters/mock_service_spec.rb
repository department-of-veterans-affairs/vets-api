# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::MockService do
  describe '.find_by_user' do
    let(:root) { Rails.root }
    before do
      allow(Rails.root).to receive(:join).and_return(root.join('config', 'evss', 'mock_letters_response.yml.example'))
    end
    it 'returns a hash of the hard coded response' do
      response = subject.get_letters
      expect(response.letters.count).to eq(8)
    end
  end
end
