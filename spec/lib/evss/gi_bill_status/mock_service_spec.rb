# frozen_string_literal: true
require 'rails_helper'

describe EVSS::GiBillStatus::MockService do
  describe '.find_by_user' do
    let(:root) { Rails.root }
    before do
      allow(Rails.root).to receive(:join).and_return(
        root.join('config', 'evss', 'mock_gi_bill_status_response.yml.example')
      )
    end
    it 'returns a hash of the hard coded response' do
      response = subject.get_gi_bill_status
      expect(response).to_not be_nil
    end
  end
end
