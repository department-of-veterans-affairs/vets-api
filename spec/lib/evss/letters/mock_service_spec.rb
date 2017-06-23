# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::MockService do
  describe '.find_by_user' do
    let(:root) { Rails.root }
    let(:user) { build(:loa3_user) }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

    subject { EVSS::Letters::MockService.new(auth_headers) }

    before do
      allow(Rails.root).to receive(:join).and_return(root.join('config', 'evss', 'mock_letters_response.yml.example'))
    end

    describe 'get_letters' do
      it 'returns a hash of the hard coded response' do
        response = subject.get_letters
        expect(response.letters.count).to eq(8)
      end
    end

    describe 'get_letter_beneficiary' do
      it 'returns a hash of the hard coded response' do
        response = subject.get_letter_beneficiary
        expect(response.military_service.count).to eq(2)
      end
    end
  end
end
