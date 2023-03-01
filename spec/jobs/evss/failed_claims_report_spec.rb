# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/api'

RSpec.describe EVSS::FailedClaimsReport, type: :job do
  describe '#extract_info' do
    test_method(
      described_class.new,
      'get_evss_metadata',
      [
        [
          'evss_claim_documents/e97131834b5d4099a571201805b4149b/565656/foo.pdf',
          {
            user_uuid: 'e97131834b5d4099a571201805b4149b',
            tracked_item_id: 565_656,
            file_name: 'foo.pdf'
          }
        ],
        [
          'evss_claim_documents/e97131834b5d4099a571201805b4149b/foo.pdf',
          {
            user_uuid: 'e97131834b5d4099a571201805b4149b',
            tracked_item_id: nil,
            file_name: 'foo.pdf'
          }
        ],
        [
          'evss_claim_documents/e97131834b5d4099a571201805b4149b/null/foo.pdf',
          {
            user_uuid: 'e97131834b5d4099a571201805b4149b',
            tracked_item_id: nil,
            file_name: 'foo.pdf'
          }
        ]
      ]
    )
  end

  describe '#get_document_hash' do
    let(:user_uuid) { 'e97131834b5d4099a571201805b4149b' }
    let(:document_hash) do
      {
        'evss_claim_id' => 123,
        'tracked_item_id' => 1234,
        'document_type' => 'L029',
        'file_name' => 'foo.pdf'
      }
    end

    before do
      job = double
      args = [
        {},
        user_uuid,
        document_hash
      ]
      allow(job).to receive(:args).and_return(args)

      expect(Sidekiq::DeadSet).to receive(:new).once.and_return([job])
    end

    context 'with valid metadata' do
      it 'gets the document hash from sidekiq' do
        expect(
          subject.get_document_hash(
            user_uuid: user_uuid,
            tracked_item_id: 1234,
            file_name: 'foo.pdf'
          )
        ).to eq(document_hash)
      end
    end

    context 'with no match' do
      it 'returns nil' do
        expect(
          subject.get_document_hash(
            user_uuid: user_uuid,
            tracked_item_id: 123,
            file_name: 'foo.pdf'
          )
        ).to eq(nil)
      end
    end
  end

  describe '#perform' do
    it 'lookups claims on s3 and send the email' do
      s3 = double
      bucket = double
      objects = [double, double]
      old_last_modified = 45.days.ago

      objects.each_with_index do |object, i|
        last_modified = i.zero? ? 5.days.ago : old_last_modified
        allow(object).to receive(:last_modified).and_return(last_modified)
        allow(object).to receive(:key).and_return("object#{i}")
      end

      expect(Aws::S3::Resource).to receive(:new).once.with(
        {
          access_key_id: 'EVSS_S3_AWS_ACCESS_KEY_ID_XYZ',
          secret_access_key: 'EVSS_S3_AWS_SECRET_ACCESS_KEY_XYZ',
          region: 'evss_s3_region'
        }
      ).and_return(s3)
      allow(s3).to receive(:bucket).twice.and_return(bucket)
      allow(bucket).to receive(:objects).and_return(objects)
      allow_any_instance_of(described_class).to receive(:get_evss_metadata).with('object1').and_return({})
      allow_any_instance_of(described_class).to receive(:get_document_hash).with({}).and_return(nil)

      expect(FailedClaimsReportMailer).to receive(:build).once.with(
        [
          {
            file_path: 'object1',
            last_modified: old_last_modified,
            document_hash: nil
          }
        ] * 2
      ).and_return(double.tap do |mailer|
        expect(mailer).to receive(:deliver_now).once
      end)

      subject.perform
    end
  end
end
