# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::BranchOfService::Serializer do
  let(:info) { { code: 'USMA', description: 'US Military Academy' } }
  let(:service) { AskVAApi::BranchOfService::Entity.new(info) }
  let(:response) { described_class.new(service) }
  let(:expected_response) do
    { data:
     { id: nil,
       type: :branch_of_service,
       attributes: {
         code: info[:code],
         description: info[:description]
       } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
