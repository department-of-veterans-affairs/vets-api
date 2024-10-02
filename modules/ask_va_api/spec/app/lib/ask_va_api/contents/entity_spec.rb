# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Contents::Entity do
  subject(:content) { described_class }

  let(:info) do
    { Name: 'Report Broken Links (provide link inform)',
      Id: '792dbcee-eb64-eb11-bb23-000d3a579b83',
      ParentId: 'f0ba9562-e864-eb11-bb23-000d3a579c44',
      Description: nil,
      RequiresAuthentication: false,
      AllowAttachments: false,
      RankOrder: 0,
      DisplayName: nil,
      TopicType: 'Category',
      ContactPreferences: [] }
  end

  let(:category) { content.new(info) }

  it 'creates an category' do
    expect(category).to have_attributes({
                                          name: info[:Name],
                                          allow_attachments: info[:AllowAttachments],
                                          description: info[:Description],
                                          display_name: info[:DisplayName],
                                          id: info[:Id],
                                          parent_id: info[:ParentId],
                                          rank_order: info[:RankOrder],
                                          requires_authentication: info[:RequiresAuthentication],
                                          topic_type: info[:TopicType],
                                          contact_preferences: info[:ContactPreferences]
                                        })
  end
end
