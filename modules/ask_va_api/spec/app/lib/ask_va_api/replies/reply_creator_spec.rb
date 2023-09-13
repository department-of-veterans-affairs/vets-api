# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Replies::ReplyCreator do
  subject(:creator) { described_class.new(inquiry_number:).call }

  let(:inquiry_number) { 'A-9' }

  it 'returns an Inquiry object' do
    expect(creator).to be_a(AskVAApi::Replies::Reply)
  end
end
