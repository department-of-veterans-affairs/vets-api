# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::DeleteOldUploads do
  let(:job) { described_class.new }

  describe '#uuids_to_keep' do
    it 'should get the uuids of attachments in in progress forms' do
      create(
        :in_progress_form,
        form_id: '40-10007',
        form_data: build(:burial_form).as_json.to_json
      )

      expect(job.uuids_to_keep).to eq(FormAttachment.pluck(:guid))
    end
  end

  describe '#perform' do
    it 'deletes attachments older than 2 months that arent associated with an in progress form' do

      described_class.new.perform
      binding.pry; fail
    end
  end
end
