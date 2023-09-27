# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KmsRecordRotationJob do
  describe '#perform' do
    before do
      HCAAttachment.create(file_data: 'testing 1')
      HCAAttachment.create(file_data: 'testing 2')
    end

    it 'updates/rotates the records with args/models passed in' do
      KmsRecordRotationJob.new.perform(['HCAAttachment'])

      all_record_encryption_keys = HCAAttachment.all.select(&:encrypted_kms_key)
      expect(all_record_encryption_keys).not_to include nil
    end

    it 'updates/rotates the records with no args' do
      KmsRecordRotationJob.new.perform

      models = ApplicationRecord.descendants_using_encryption.map(&:name).map(&:constantize)

      models.each do |model|
        all_record_encryption_keys = model.all.select(&:encrypted_kms_key)
        expect(all_record_encryption_keys).not_to include nil
      end
    end
  end
end
