# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::DeleteOldUploadsJob do
  it 'inherits DeleteAttachmentJob' do
    expect(described_class.ancestors).to include(DeleteAttachmentJob)
  end

  describe '::ATTACHMENT_CLASSES' do
    it 'is references the attachment model\'s name' do
      expect(described_class::ATTACHMENT_CLASSES).to eq(['Form1010cg::Attachment'])
    end
  end

  describe '::FORM_ID' do
    it 'is references the form\'s id' do
      expect(described_class::FORM_ID).to eq('10-10CG')
    end
  end

  describe '::EXPIRATION_TIME' do
    it 'is set to 30 days' do
      expect(described_class::EXPIRATION_TIME).to eq(30.days)
    end
  end

  describe '#uuids_to_keep' do
    it 'returns an empty array' do
      expect(subject.uuids_to_keep).to eq([])
    end
  end

  describe '#perform' do
    it 'deletes attachments created more than 30 days ago' do
      Timecop.freeze(DateTime.new(2025, 6, 25)) do
        now = DateTime.now

        old_attachment = create(:form1010cg_attachment, :with_attachment, created_at: now - 31.days)
        older_attachment = create(:form1010cg_attachment, :with_attachment, created_at: now - 32.days)
        newer_attachment = create(:form1010cg_attachment, :with_attachment, created_at: now - 29.days)

        allow_any_instance_of(Form1010cg::Attachment).to receive(:get_file).and_return(double(delete: true))

        subject.perform

        expect { old_attachment.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { older_attachment.reload }.to raise_error(ActiveRecord::RecordNotFound)

        expect(Form1010cg::Attachment.all).to eq([newer_attachment])
        expect(Form1010cg::Attachment.count).to eq(1)
      end
    end
  end
end
