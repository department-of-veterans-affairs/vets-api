# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HigherLevelReviewSubmission, type: :model do
  subject { create(:higher_level_review_submission) }

  context 'encrypted attributes' do
    it('encrypts form_data') { is_expected.to encrypt_attr(:form_data) }
    it('encrypts file_data') { is_expected.to encrypt_attr(:file_data) }
    it('encrypts auth_headers') { is_expected.to encrypt_attr(:auth_headers) }
  end

=begin
  describe '#set_file_data!' do
    it 'stores the file_data and give me a full evss document' do
      attachment = build(:power_of_attorney)

      file = Rack::Test::UploadedFile.new(
        "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
      )

      attachment.set_file_data!(file, 'docType')
      attachment.save!
      attachment.reload

      expect(attachment.file_data).to have_key('filename')
      expect(attachment.file_data).to have_key('doc_type')

      expect(attachment.file_name).to eq(attachment.file_data['filename'])
      expect(attachment.document_type).to eq(attachment.file_data['doc_type'])
    end
  end

  describe 'pending?' do
    context 'no pending records' do
      it 'is false' do
        expect(described_class.pending?('123')).to be(false)
      end
    end

    context 'with pending records' do
      it 'truthies and return the record' do
        result = described_class.pending?(pending_record.id)
        expect(result).to be_truthy
        expect(result.id).to eq(pending_record.id)
      end
    end
  end
=end
end
