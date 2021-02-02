# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreementSerializer do
  it 'serializes the NOD properly' do
    notice_of_disagreement = create(:notice_of_disagreement)

    rendered_hash = described_class.new(notice_of_disagreement).serializable_hash

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
    expect(rendered_hash[:data][:type]).to eq :noticeOfDisagreement
    expect(rendered_hash).to eq(
      {
        data: {
          type: :noticeOfDisagreement,
          id: notice_of_disagreement.id,
          attributes: {
            status: notice_of_disagreement.status,
            createdAt: notice_of_disagreement.created_at,
            updatedAt: notice_of_disagreement.updated_at,
            formData: notice_of_disagreement.form_data
          }
        }
      }
    )
  end
end
