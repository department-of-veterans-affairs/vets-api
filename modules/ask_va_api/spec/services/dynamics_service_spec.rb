# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DynamicsService do
  subject(:service) { described_class.new }

  describe '#get_user_inquiries' do
    let(:user_inquiries) { service.get_user_inquiries(uuid: '6400bbf301eb4e6e95ccea7693eced6f') }

    it 'returns user_inquiries' do
      expect(user_inquiries).to be_an(Array)
    end
  end

  describe '#get_inquiry' do
    let(:inquiry) { service.get_inquiry(inquiry_number: 'A-1') }

    it 'returns an inquiry' do
      expect(inquiry).to be_a(Hash)
    end
  end
end
