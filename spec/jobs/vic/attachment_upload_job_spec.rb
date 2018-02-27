# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::AttachmentUploadJob do
  describe '#perform' do
    it 'should call send_files' do
      vic_submission = create(:vic_submission)
      form = vic_submission.form

      expect_any_instance_of(VIC::Service).to receive(:send_files).with(
        'case_id',
        JSON.parse(form)
      )

      described_class.new.perform('case_id', vic_submission.form)
    end
  end
end
