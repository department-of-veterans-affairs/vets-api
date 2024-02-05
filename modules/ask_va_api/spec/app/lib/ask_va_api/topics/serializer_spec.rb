# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Topics::Serializer do
  let(:info) do
    { name: 'Report Broken Links (provide link inform)',
      id: '792dbcee-eb64-eb11-bb23-000d3a579b83',
      parentId: 'f0ba9562-e864-eb11-bb23-000d3a579c44',
      description: nil,
      requiresAuthentication: false,
      allowAttachments: false,
      rankOrder: 0,
      displayName: nil }
  end
  let(:category) { AskVAApi::Topics::Entity.new(info) }
  let(:response) { described_class.new(category) }
  let(:expected_response) do
    { data: { id: '792dbcee-eb64-eb11-bb23-000d3a579b83',
              type: :topics,
              attributes: {
                name: info[:name],
                allow_attachments: info[:allowAttachments],
                description: info[:description],
                display_name: info[:displayName],
                parent_id: info[:parentId],
                rank_order: info[:rankOrder],
                requires_authentication: info[:requiresAuthentication]
              } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
