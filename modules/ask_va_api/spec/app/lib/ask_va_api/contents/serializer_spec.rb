# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Contents::Serializer do
  let(:info) do
    {
      Name: 'Report Broken Links (provide link inform)',
      Id: '792dbcee-eb64-eb11-bb23-000d3a579b83',
      ParentId: 'f0ba9562-e864-eb11-bb23-000d3a579c44',
      Description: nil,
      RequiresAuthentication: false,
      AllowAttachments: false,
      RankOrder: 0,
      DisplayName: nil,
      TopicType: 'Category',
      ContactPreferences: []
    }
  end
  let(:content) { AskVAApi::Contents::Entity.new(info) }
  let(:response) { described_class.new(content) }
  let(:expected_response) do
    { data: { id: '792dbcee-eb64-eb11-bb23-000d3a579b83',
              type: :contents,
              attributes: {
                name: info[:Name],
                allow_attachments: info[:AllowAttachments],
                description: info[:Description],
                display_name: info[:DisplayName],
                parent_id: info[:ParentId],
                rank_order: info[:RankOrder],
                requires_authentication: info[:RequiresAuthentication],
                topic_type: info[:TopicType],
                contact_preferences: info[:ContactPreferences]
              } } }
  end

  context 'when successful' do
    it 'returns a json hash' do
      expect(response.serializable_hash).to include(expected_response)
    end
  end
end
