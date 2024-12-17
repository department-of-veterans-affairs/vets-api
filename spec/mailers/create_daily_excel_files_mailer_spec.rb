# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateDailyExcelFilesMailer, type: %i[mailer aws_helpers] do
  describe 'excel mailer' do
    subject do
      described_class.build('eastern').deliver_now
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'emails the the right recipients' do
        expect(subject.to).to eq(
          %w[
            alex.chan1@va.gov
          ]
        )
      end
    end
  end
end
