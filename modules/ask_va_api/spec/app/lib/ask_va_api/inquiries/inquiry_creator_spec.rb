# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::InquiryCreator do
  subject(:creator) { described_class.new(inquiry_number:).call }

  let(:inquiry_number) { 'A-1' }

  before do
    allow(AskVAApi::Replies::Reply).to receive(:new).and_call_original
  end

  it 'returns an Inquiry object' do
    expect(creator).to be_a(AskVAApi::Inquiries::Inquiry)
  end

  it 'calls on AskVAApi::Replies::Reply' do
    creator

    expect(AskVAApi::Replies::Reply).to have_received(:new)
  end
end
