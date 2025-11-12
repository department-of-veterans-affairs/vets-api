# frozen_string_literal: true

require 'rails_helper'
require 'persistent_attachments/sanitizer'

RSpec.describe PersistentAttachments::Sanitizer do
  let(:claim) do
    build(:fake_saved_claim)
  end
  let(:bad_attachment) { PersistentAttachment.create!(saved_claim_id: claim.id) }
  let(:good_attachment) { PersistentAttachment.create!(saved_claim_id: claim.id) }
  let(:form_data_hash) do
    {
      'files' => [
        { 'confirmationCode' => bad_attachment.guid },
        { 'confirmationCode' => good_attachment.guid }
      ]
    }
  end
  let(:form_data_json) { form_data_hash.to_json }
  let(:in_progress_form) { double('InProgressForm', form_data: form_data_json, id: 123, metadata: {}) }

  before do
    allow(claim).to receive_messages(
      attachment_keys: [:files],
      open_struct_form: OpenStruct.new(files: [OpenStruct.new(confirmationCode: bad_attachment.guid),
                                               OpenStruct.new(confirmationCode: good_attachment.guid)])
    )
    allow_any_instance_of(PersistentAttachment).to receive(:file_data) do |attachment|
      raise StandardError if attachment.guid == bad_attachment.guid

      'filedata'
    end
    allow(in_progress_form).to receive(:update!)
  end

  describe '#sanitize_attachments' do
    it 'destroys bad attachments, removes them from form_data, and updates the in_progress_form' do
      expect do
        described_class.new.sanitize_attachments(claim, in_progress_form)
      end.to change { PersistentAttachment.where(id: bad_attachment.id).count }
        .from(1).to(0)
    end

    it 'logs errors if an exception is raised' do
      allow(in_progress_form).to receive(:update!).and_raise(StandardError, 'update failed')
      monitor = instance_double(Logging::Monitor)
      allow(Logging::Monitor).to receive(:new).and_return(monitor)
      expect(monitor).to receive(:track_request).with(
        :error,
        'PersistentAttachments::Sanitizer sanitize attachments error',
        'api.persistent_attachments.sanitize_attachments_error',
        hash_including(:claim, :in_progress_form_id, :errors, :error, :call_location)
      )

      described_class.new.sanitize_attachments(claim, in_progress_form)
    end
  end

  describe '#process_attachments_for_key' do
    let(:form_data) do
      OpenStruct.new(files: [OpenStruct.new(confirmationCode: bad_attachment.guid),
                             OpenStruct.new(confirmationCode: good_attachment.guid)])
    end

    it 'removes only the bad attachment from the OpenStruct array' do
      expect do
        described_class.new.process_attachments_for_key(claim, :files, form_data)
      end.to change { PersistentAttachment.where(id: bad_attachment.id).count }
        .from(1).to(0)
      codes = form_data.files.map(&:confirmationCode)
      expect(codes).to eq([good_attachment.guid])
    end
  end
end
