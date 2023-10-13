# frozen_string_literal: true

require 'rails_helper'

GeneralError = Class.new(StandardError)

RSpec.describe KmsKeyRotation::RotateKeysJob, type: :job do
  let(:job) { described_class.new }
  let(:records) { create_list(:burial_claim, 3) }
  let(:args) { records.map(&:to_global_id) }

  describe '#perform' do
    it 'calls rotate_kms_key! on each record' do
      allow(GlobalID::Locator).to receive(:locate_many).and_return(records)

      expect(records).to all(receive(:rotate_kms_key!))
      job.perform(args)
    end

    it 'skips and resets the callback' do
      expect(HealthQuest::QuestionnaireResponse).to receive(:skip_callback).once
      expect(HealthQuest::QuestionnaireResponse).to receive(:set_callback).once

      job.perform(args)
    end
  end

  describe '#rotate_kms_key' do
    it 'rotating keys without updating timestamps' do
      record = records[0]
      initial_updated_at = record.updated_at
      initial_encrypted_kms_key = record.encrypted_kms_key

      record.rotate_kms_key!

      expect(record.updated_at).to eq(initial_updated_at)
      expect(record.encrypted_kms_key).not_to eq(initial_encrypted_kms_key)
    end
  end
end
