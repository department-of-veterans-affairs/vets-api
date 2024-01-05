# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Topics::Entity do
  subject(:creator) { described_class }

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
  let(:topic) { creator.new(info) }

  it 'creates an topic' do
    expect(topic).to have_attributes({
                                       name: info[:name],
                                       allow_attachments: info[:allowAttachments],
                                       description: info[:description],
                                       display_name: info[:displayName],
                                       id: info[:id],
                                       parent_id: info[:parentId],
                                       rank_order: info[:rankOrder],
                                       requires_authentication: info[:requiresAuthentication]
                                     })
  end
end
