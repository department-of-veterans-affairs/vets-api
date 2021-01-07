# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

module AppealsApi
  RSpec.describe RemovePii do
    describe '#run!' do
      it 'raises an ArgumentError if an invalid form type is supplied' do
        expect { RemovePii.new(form_type: 'Invalid').run! }.to raise_error(ArgumentError)
      end

      it 'removes PII from HLR records needing PII removal' do
        has_pii = create :higher_level_review, :completed_a_week_ago

        expect(has_pii.encrypted_form_data).not_to be_nil

        RemovePii.new(form_type: HigherLevelReview).run!

        expect(has_pii.reload.encrypted_form_data).to be_nil
      end

      it 'removes PII from NOD records needing PII removal' do
        has_pii = create :notice_of_disagreement, :completed_a_week_ago

        expect(has_pii.encrypted_form_data).not_to be_nil

        RemovePii.new(form_type: NoticeOfDisagreement).run!

        expect(has_pii.reload.encrypted_form_data).to be_nil
      end

      it 'sends a message to sentry if the removal failed.' do
        allow_any_instance_of(RemovePii).to receive(:records_were_not_cleared).and_return(true)
        service = RemovePii.new(form_type: NoticeOfDisagreement)
        expect(service).to receive(:log_failure_to_sentry)

        service.run!
      end
    end
  end
end
