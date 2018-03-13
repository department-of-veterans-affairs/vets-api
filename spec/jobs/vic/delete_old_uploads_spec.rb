# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::DeleteOldUploads do
  before do
  end

  describe 'query methods' do
    before do
      FactoryBot.create(
        :in_progress_form,
        form_id: 'VIC',
        form_data: form_data.to_json
      )
    end

    describe '#photos_to_keep' do
      let(:photo) { FactoryBot.create(:profile_photo_attachment) }
      let(:form_data) do
        { 'photo' => { 'confirmationCode' => photo.guid } }
      end

      it 'finds photos that should be kept' do
        expect(described_class.new.photos_to_keep.length).to eq(1)
      end
    end

    describe '#docs_to_keep' do
      let(:doc) { FactoryBot.create(:supporting_documentation_attachment) }
      let(:form_data) do
        { 'dd214' => { 'confirmationCode' => doc.guid } }
      end

      it 'finds docs that should be kept' do
        expect(described_class.new.docs_to_keep.length).to eq(1)
      end
    end
  end

  describe '#perform' do
    it 'checks for uploads to keep from in progress forms' do
      expect_any_instance_of(VIC::DeleteOldUploads).to receive(:photos_to_keep)
      expect_any_instance_of(VIC::DeleteOldUploads).to receive(:docs_to_keep)

      described_class.new.perform
      described_class.drain
    end
  end
end
