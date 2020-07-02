# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReviewSerializer do
  it('serializes') do
    hlr = create(:higher_level_review)

    # rendered_hash = ActiveModelSerializers::SerializableResource.new(
    #   hlr, serializer: described_class
    # ).serializable_hash

    rendered_hash = described_class.new(hlr).serializable_hash

    expect(rendered_hash.keys.count).to be 1
    expect(rendered_hash).to have_key :data
    expect(rendered_hash[:data].keys.count).to be 3
    expect(rendered_hash[:data]).to have_key :type
    expect(rendered_hash[:data]).to have_key :id
    expect(rendered_hash[:data]).to have_key :attributes
    expect(rendered_hash[:data][:attributes].keys.count).to be 4
    expect(rendered_hash[:data][:attributes]).to have_key :status
    expect(rendered_hash[:data][:attributes]).to have_key :created_at
    expect(rendered_hash[:data][:attributes]).to have_key :updated_at
    expect(rendered_hash[:data][:attributes]).to have_key :form_data
    expect(rendered_hash[:data][:type]).to eq :higherLevelReviewInfo
    expect(rendered_hash).to eq(
      {
        data: {
          type: :higherLevelReviewInfo,
          id: hlr.id,
          attributes: {
            status: hlr.status,
            created_at: hlr.created_at,
            updated_at: hlr.updated_at,
            form_data: hlr.form_data
          }
        }
      }
    )
  end
end
