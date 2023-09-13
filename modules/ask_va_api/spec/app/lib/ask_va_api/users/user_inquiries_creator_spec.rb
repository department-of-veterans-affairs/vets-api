# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Users::UserInquiriesCreator do
  subject(:creator) { described_class.new(uuid:).call }

  let(:uuid) { '6400bbf301eb4e6e95ccea7693eced6f' }

  describe '#call' do
    it 'returns a UserInquiries object with correct attributes' do
      expect(creator).to be_a(AskVAApi::Users::UserInquiries)
      expect(creator.id).to be_nil
      expect(creator.inquiries).to be_an(Array)
    end
  end
end
