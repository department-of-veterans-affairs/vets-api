# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReviewSerializer do
  it('serializes') do
    hlr = create(:higher_level_review)

    rendered_hash = described_class.new(hlr).serializable_hash

    expect(rendered_hash.keys.count).to be 1
    expect(rendered_hash).to have_key :data
    expect(rendered_hash[:data].keys.count).to be 3
    expect(rendered_hash[:data]).to have_key :type
    expect(rendered_hash[:data]).to have_key :id
    expect(rendered_hash[:data]).to have_key :attributes
    expect(rendered_hash[:data][:attributes].keys.count).to be 4
    expect(rendered_hash[:data][:attributes]).to have_key :status
    expect(rendered_hash[:data][:attributes]).to have_key :createdAt
    expect(rendered_hash[:data][:attributes]).to have_key :updatedAt
    expect(rendered_hash[:data][:attributes]).to have_key :formData
    expect(rendered_hash[:data][:type]).to eq :higherLevelReview
    expect(rendered_hash).to eq(
      {
        data: {
          type: :higherLevelReview,
          id: hlr.id,
          attributes: {
            status: hlr.status,
            createdAt: hlr.created_at,
            updatedAt: hlr.updated_at,
            formData: hlr.form_data
          }
        }
      }
    )
  end
end
