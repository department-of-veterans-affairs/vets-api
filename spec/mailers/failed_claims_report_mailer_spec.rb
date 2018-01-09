# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FailedClaimsReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(
        [
          {
            file_path: 'dir1/file1<b>.txt',
            last_modified: Time.new(2016).utc.beginning_of_year,
            document_hash: {
              'evss_claim_id' => 123,
              'tracked_item_id' => 1234,
              'document_type' => 'L029',
              'file_name' => 'file1<b>.txt'
            }
          },
          {
            file_path: 'dir1/file2.txt',
            last_modified: Time.new(2017).utc.beginning_of_year,
            document_hash: {
              'evss_claim_id' => 123,
              'tracked_item_id' => 1234,
              'document_type' => 'L029',
              'file_name' => 'file2.txt'
            }
          },
          {
            file_path: 'dir1/file3.txt',
            last_modified: Time.new(2015).utc.beginning_of_year,
            document_hash: nil
          }
        ]
      ).deliver_now
    end

    it 'should send the right email' do
      expect(subject.body.raw_source).to eq(File.read('spec/fixtures/evss_claim/failed_claims_report.html'))
      expect(subject.subject).to eq('EVSS claims failed to upload')
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'should email the the right recipients' do
        expect(subject.to).to eq(
          %w(
            lihan@adhocteam.us
            ryan.baker@adhocteam.us
          )
        )
      end
    end
  end
end
