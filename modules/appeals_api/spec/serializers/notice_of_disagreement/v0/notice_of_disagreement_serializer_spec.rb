# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementSerializer do
  let(:notice_of_disagreement) { create(:notice_of_disagreement_v0) }
  let(:rendered_hash) { described_class.new(notice_of_disagreement).serializable_hash }

  it 'serializes the NOD properly' do
    expect(rendered_hash).to eq(
      {
        data: {
          id: notice_of_disagreement.id,
          type: :noticeOfDisagreement,
          attributes: {
            status: notice_of_disagreement.status,
            createDate: notice_of_disagreement.created_at,
            updateDate: notice_of_disagreement.updated_at
          }
        }
      }
    )
  end

  context 'when NOD is in error state' do
    let(:status) { 'error' }
    let(:code) { '999' }
    let(:detail) { 'detail text' }
    let(:notice_of_disagreement) { create(:notice_of_disagreement_v0, status:, code:, detail:) }

    it 'serializes the NOD properly, including error attributes' do
      expect(rendered_hash).to eq(
        {
          data: {
            id: notice_of_disagreement.id,
            type: :noticeOfDisagreement,
            attributes: {
              status:,
              createDate: notice_of_disagreement.created_at,
              updateDate: notice_of_disagreement.updated_at,
              code:,
              detail:
            }
          }
        }
      )
    end
  end
end
