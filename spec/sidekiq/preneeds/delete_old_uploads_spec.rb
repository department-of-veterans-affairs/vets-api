# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::DeleteOldUploads, type: :model do
  let(:job) { described_class.new }

  describe '::EXPIRATION_TIME' do
    it 'is 2.months' do
      expect(described_class::EXPIRATION_TIME).to eq(2.months)
    end
  end

  describe '#uuids_to_keep' do
    it 'gets the uuids of attachments in in progress forms' do
      create(
        :in_progress_form,
        form_id: '40-10007',
        form_data: build(:burial_form).as_json.to_json
      )

      expect(job.uuids_to_keep).to match_array(FormAttachment.pluck(:guid))
    end
  end

  describe '#perform' do
    it 'deletes attachments older than 2 months that arent associated with an in progress form' do
      attach1 = create(:preneed_attachment)
      attach2 = create(:preneed_attachment, created_at: 3.months.ago)
      attach3 = create(:preneed_attachment, created_at: 3.months.ago)

      expect(job).to receive(:uuids_to_keep).and_return([attach3.guid])

      job.perform
      expect(model_exists?(attach1)).to be(true)
      expect(model_exists?(attach2)).to be(false)
      expect(model_exists?(attach3)).to be(true)
    end
  end
end
