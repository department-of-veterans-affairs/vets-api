# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::PowerOfAttorney, type: :model do
  let(:pending_record) { create(:power_of_attorney) }

  describe 'encrypted attributes' do
    it 'does the thing' do
      expect(subject).to encrypt_attr(:form_data)
      expect(subject).to encrypt_attr(:auth_headers)
    end
  end

  describe 'encrypted attribute' do
    it 'does the thing' do
      expect(subject).to encrypt_attr(:file_data)
    end
  end

  describe '#set_file_data!' do
    it 'stores the file_data and give me a full evss document' do
      attachment = build(:power_of_attorney)

      file = Rack::Test::UploadedFile.new(
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
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

  describe "persisting 'cid' (OKTA client_id)" do
    it "stores 'cid' in the DB upon creation" do
      pending_record.cid = 'ABC123'
      pending_record.save!

      claim = ClaimsApi::PowerOfAttorney.last

      expect(claim.cid).to eq('ABC123')
    end
  end
end
