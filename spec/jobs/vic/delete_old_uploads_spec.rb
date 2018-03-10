# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::DeleteOldUploads do
  before do
  end

  describe '#perform' do
    let(:photo_guid) { SecureRandom.uuid }
    let(:doc_guid) { SecureRandom.uuid }

    before do
      FactoryBot.create(
        :in_progress_form,
        form_id: 'vic',
        form_data: {
          'dd214' => { 'confirmationCode' => doc_guid },
          'photo' => { 'confirmationCode' => photo_guid }
        }.to_json
      )
    end

    it 'checks for uploads to keep from in progress forms' do
      expect_any_instance_of(VIC::DeleteOldUploads).to receive(:delete_photos).with(:foo)
      allow_any_instance_of(VIC::DeleteOldUploads).to receive(:delete_docs).with(:bar)

      VIC::DeleteOldUploads.new.perform
    end
  end
end
