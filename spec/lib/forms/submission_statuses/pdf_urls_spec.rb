# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/pdf_urls'

describe Forms::SubmissionStatuses::PdfUrls, feature: :form_submission,
                                             team_owner: :vfs_authenticated_experience_backend do
  subject { described_class.new(user_account:) }

  let(:user_account) { create(:user_account) }

  context 'supported?' do
    it 'returns true for supported forms' do
      supported = Forms::SubmissionStatuses::PdfUrls.new(
        form_id: '21-10210',
        submission_guid: 'some-uuid'
      ).supported?
      expect(supported).to be(true)
    end

    it 'returns false for unsupported forms' do
      supported = Forms::SubmissionStatuses::PdfUrls.new(
        form_id: '666-bad-id',
        submission_guid: 'some-uuid'
      ).supported?
      expect(supported).to be(false)
    end
  end
end
