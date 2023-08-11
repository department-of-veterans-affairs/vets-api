# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::InquiryCreator do
  subject(:creator) { described_class.new(inquiry_number:).call }

  let(:inquiry_number) { 'A-1' }

  it 'returns an Inquiry object' do
    expect(creator).to be_a(AskVAApi::Inquiries::Inquiry)
  end

  context 'when Inquiry is nil' do
    let(:inquiry_number) { 'Invalid Number' }

    it 'returns an error' do
      expect { creator }.to raise_error(DynamicsService::DynamicsServiceError)
    end
  end
end
