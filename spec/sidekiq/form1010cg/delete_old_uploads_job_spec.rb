# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::DeleteOldUploadsJob do
  it 'inherits DeleteAttachmentJob' do
    expect(described_class.ancestors).to include(DeleteAttachmentJob)
  end

  describe '::ATTACHMENT_CLASSES' do
    it 'is references the attachment model\'s name' do
      expect(described_class::ATTACHMENT_CLASSES).to eq(['Form1010cg::Attachment'])
    end
  end

  describe '::FORM_ID' do
    it 'is references the form\'s id' do
      expect(described_class::FORM_ID).to eq('10-10CG')
    end
  end

  describe '::EXPIRATION_TIME' do
    it 'is set to 30 days' do
      expect(described_class::EXPIRATION_TIME).to eq(30.days)
    end
  end

  describe '#uuids_to_keep' do
    it 'returns and empty array' do
      expect(subject.uuids_to_keep).to eq([])
    end
  end

  describe '#perform' do
    describe 'unit' do
      before do
        query_results = [
          double('attachment 1'),
          double('attachment 2')
        ]

        expect(query_results[0]).to receive(:destroy!).and_return(true)
        expect(query_results[1]).to receive(:destroy!).and_return(true)

        ar_query_scope_1 = double('AR scope 1')
        ar_query_scope_2 = double('AR scope 2')
        ar_query_scope_3 = double('AR scope 3')
        ar_query_scope_4 = double('AR scope 4')

        expect(FormAttachment).to receive(:where).with(
          'created_at < ?', described_class::EXPIRATION_TIME.ago
        ).and_return(ar_query_scope_1)
        expect(ar_query_scope_1).to receive(:where).with(
          type: described_class::ATTACHMENT_CLASSES
        ).and_return(ar_query_scope_2)
        expect(ar_query_scope_2).to receive(:where).and_return(ar_query_scope_3)
        expect(ar_query_scope_3).to receive(:not).with(guid: []).and_return(ar_query_scope_4)
        expect(ar_query_scope_4).to receive(:find_each).and_yield(query_results[0]).and_yield(query_results[1])
      end

      it 'calls #delete! on matching attachments', run_at: '2021-05-27 13:52:34' do
        subject.perform
      end
    end

    describe 'integration' do
      let(:now) { DateTime.now }
      let(:vcr_options) do
        {
          record: :none,
          allow_unused_http_interactions: false,
          match_requests_on: %i[method host]
        }
      end

      let(:attachment_guid_1) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' } # Must match cassette
      let(:attachment_guid_2) { '834d9f51-d0c7-4dc2-9f2e-9b722db98069' } # Must match cassette
      let(:attachment_guid_3) { '1cf90fb5-c0ab-453e-9b54-2b8307e12012' } # Must match cassette
      let(:attachment_1)      { build(:form1010cg_attachment, guid: attachment_guid_1, created_at: now - 31.days) }
      let(:attachment_2)      { build(:form1010cg_attachment, guid: attachment_guid_2, created_at: now - 32.days) }
      let(:attachment_3)      { build(:form1010cg_attachment, guid: attachment_guid_3, created_at: now - 29.days) }

      def use_cassette(cassette, &block)
        VCR.use_cassette(cassette, vcr_options) do
          block.call
        end
      end

      before do
        use_cassette("s3/object/put/#{attachment_1.guid}/doctors-note.jpg") do
          attachment_1.set_file_data!(
            Rack::Test::UploadedFile.new(
              Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg'),
              'image/jpg'
            )
          )
        end

        use_cassette("s3/object/put/#{attachment_2.guid}/doctors-note.pdf") do
          attachment_2.set_file_data!(
            Rack::Test::UploadedFile.new(
              Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf'),
              'application/pdf'
            )
          )
        end

        use_cassette("s3/object/put/#{attachment_3.guid}/doctors-note.jpg") do
          attachment_3.set_file_data!(
            Rack::Test::UploadedFile.new(
              Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg'),
              'image/jpg'
            )
          )
        end

        attachment_1.save!
        attachment_2.save!
        attachment_3.save!
      end

      it 'deletes attachments created more than 30 days ago', skip: 'VCR failures' do
        use_cassette("s3/object/delete/#{attachment_1.guid}/doctors-note.jpg") do
          use_cassette("s3/object/delete/#{attachment_2.guid}/doctors-note.pdf") do
            expect(Form1010cg::Attachment.count).to eq(3)

            subject.perform

            expect { attachment_1.reload }.to raise_error(ActiveRecord::RecordNotFound)
            expect { attachment_2.reload }.to raise_error(ActiveRecord::RecordNotFound)

            expect(Form1010cg::Attachment.all).to eq([attachment_3])
          end
        end
      end
    end
  end
end
