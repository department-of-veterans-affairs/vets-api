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
      job = VIC::DeleteOldUploads.new
      job.perform

      expect(job.instance_variable_get(:photo_files)).to eq([])
      expect(job.instance_variable_get(:doc_files)).to eq([])
    end
  end
end
