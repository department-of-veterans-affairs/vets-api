# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Serializer do
  let(:info) do
    {
      inquiryNumber: 'A-1',
      replyId: 'R-1',
      reply: 'this is a reply'
    }
  end
  let(:correspondence) { AskVAApi::Correspondences::Entity.new(info) }
  let(:response) { described_class.new(correspondence) }
  let(:expected_response) do
    { data: { id: 'R-1',
              type: :correspondence,
              attributes: { inquiry_number: 'A-1',
                            correspondence: 'this is a reply' } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
