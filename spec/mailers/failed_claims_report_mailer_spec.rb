# frozen_string_literal: true
require 'rails_helper'

RSpec.describe FailedClaimsReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(
        [
          {
            file_path: 'dir1/file1<b>.txt',
            document_hash: {
              "evss_claim_id" => 123,
              "tracked_item_id" => 1234,
              "document_type" => "L029",
              "file_name" => "file1<b>.txt"
            }
          },
          {
            file_path: 'dir1/file2.txt',
            document_hash: {
              "evss_claim_id" => 123,
              "tracked_item_id" => 1234,
              "document_type" => "L029",
              "file_name" => "file2.txt"
            }
          }
        ]
      ).deliver_now
    end

    it 'should send the right email' do
      expect(subject.body.encoded).to eq("<table>\r\n  <tr>\r\n    <th>File path</th>\r\n    <th>Meta data</th>\r\n  </tr>\r\n  \r\n    <tr>\r\n      <td>\r\n        dir1/file1&lt;b&gt;.txt\r\n      </td>\r\n      <td>\r\n        {&quot;evss_claim_id&quot;:123,&quot;tracked_item_id&quot;:1234,&quot;document_type&quot;:&quot;L029&quot;,&quot;file_name&quot;:&quot;file1&lt;b&gt;.txt&quot;}\r\n      </td>\r\n    </tr>\r\n  \r\n    <tr>\r\n      <td>\r\n        dir1/file2.txt\r\n      </td>\r\n      <td>\r\n        {&quot;evss_claim_id&quot;:123,&quot;tracked_item_id&quot;:1234,&quot;document_type&quot;:&quot;L029&quot;,&quot;file_name&quot;:&quot;file2.txt&quot;}\r\n      </td>\r\n    </tr>\r\n  \r\n</table>\r\n")
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
            mark@adhocteam.us
          )
        )
      end
    end
  end
end
