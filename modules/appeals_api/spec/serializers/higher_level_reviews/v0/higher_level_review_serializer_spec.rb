# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReviews::V0::HigherLevelReviewSerializer do
  let(:higher_level_review) { create(:higher_level_review_v0) }
  let(:rendered_hash) { described_class.new(higher_level_review).serializable_hash }

  it 'serializes the HLR properly' do
    expect(rendered_hash).to eq(
      {
        data: {
          type: :higherLevelReview,
          id: higher_level_review.id,
          attributes: {
            status: higher_level_review.status,
            createDate: higher_level_review.created_at,
            updateDate: higher_level_review.updated_at,
            formData: higher_level_review.form_data
          }
        }
      }
    )
  end
end
