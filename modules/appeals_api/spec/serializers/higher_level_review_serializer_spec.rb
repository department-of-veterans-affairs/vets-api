# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReviewSerializer do
  let(:higher_level_review) { create(:higher_level_review_v2) }
  let(:rendered_hash) { described_class.new(higher_level_review).serializable_hash }

  it 'serializes the HLR properly' do
    expect(rendered_hash).to eq(
      {
        data: {
          type: :higherLevelReview,
          id: higher_level_review.id,
          attributes: {
            status: higher_level_review.status,
            createdAt: higher_level_review.created_at,
            updatedAt: higher_level_review.updated_at,
            formData: higher_level_review.form_data
          }
        }
      }
    )
  end

  it 'has the correct top level keys' do
    expect(rendered_hash.keys.count).to be 1
    expect(rendered_hash).to have_key :data
  end

  it 'has the correct data keys' do
    expect(rendered_hash[:data].keys.count).to be 3
    expect(rendered_hash[:data]).to have_key :type
    expect(rendered_hash[:data]).to have_key :id
    expect(rendered_hash[:data]).to have_key :attributes
  end

  it 'has the correct attribute keys' do
    expect(rendered_hash[:data][:attributes].keys.count).to be 4
    expect(rendered_hash[:data][:attributes]).to have_key :status
    expect(rendered_hash[:data][:attributes]).to have_key :createdAt
    expect(rendered_hash[:data][:attributes]).to have_key :updatedAt
    expect(rendered_hash[:data][:attributes]).to have_key :formData
  end

  it 'has the correct type' do
    expect(rendered_hash[:data][:type]).to eq :higherLevelReview
  end
end
