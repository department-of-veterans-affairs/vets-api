# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::HigherLevelReviewSerializer do
  it('serializes') do
    hlr = create(:higher_level_review)

    rendered_hash = ActiveModelSerializers::SerializableResource.new(
      hlr, serializer: described_class
    ).serializable_hash

    expect(rendered_hash).to eq(
      {
        data: {
          type: hlr.class.table_name.singularize,
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
