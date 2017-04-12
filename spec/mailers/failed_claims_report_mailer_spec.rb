# frozen_string_literal: true
require 'rails_helper'

RSpec.describe FailedClaimsReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(
        %w(
          dir1/file1<b>.txt
          dir2/file2.pdf
        )
      ).deliver_now
    end

    it 'should send the right email' do
      expect(subject.body.encoded).to eq('dir1/file1&lt;b&gt;.txt<br>dir2/file2.pdf')
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
