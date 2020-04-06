# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HigherLevelReviewSubmission, type: :model do
  let(:higher_level_review_submission) do
    AppealsApi::HigherLevelReviewSubmission.new(
      form_data: form_data,
      auth_headers: auth_headers
    )
  end

  let(:auth_headers) { {} }
  let(:form_data) { default_form_data }
  let(:default_form_data) do
    JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/valid_200996.json"
  end

  describe '.receipt_date' do
    subject { higher_level_review_submission.receipt_date }

    context 'new hlr submission; receiptDate not given' do
      let(:form_data) do
        json = default_form_data
        json['data']['attributes'] = json['data']['attributes'].except 'receiptDate'
        json
      end

      it 'uses today\'s date' do
        expect(subject.strftime('%F')).to eq Time.now.utc.strftime('%F')
      end
    end
  end
end
