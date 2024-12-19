# frozen_string_literal: true

require 'rails_helper'
require 'claim_documents/monitor'

RSpec.describe ClaimDocuments::Monitor do
  let(:service) { OpenStruct.new(uuid: 'uuid') }
  let(:monitor) { described_class.new(service) }
  let(:document_stats_key) { described_class::DOCUMENT_STATS_KEY }
  let(:form_id) { '21P-527EZ' }
  let(:attachment_id) { '12345' }
  let(:current_user) { create(:user) }
  let(:error) { StandardError.new('An error occurred') }

  describe '#track_document_upload_attempt' do
    it 'logs an upload attempt' do
      expect(StatsD).to receive(:increment).with("#{document_stats_key}.attempt", tags: ["form_id:#{form_id}"])
      expect(Rails.logger).to receive(:info).with(
        "Creating PersistentAttachment FormID=#{form_id}",
        hash_including(user_account_uuid: current_user.user_account_uuid, statsd: "#{document_stats_key}.attempt")
      )

      monitor.track_document_upload_attempt(form_id, current_user)
    end
  end

  describe '#track_document_upload_success' do
    it 'logs a successful upload' do
      expect(StatsD).to receive(:increment).with("#{document_stats_key}.success", tags: ["form_id:#{form_id}"])
      expect(Rails.logger).to receive(:info).with(
        "Success creating PersistentAttachment FormID=#{form_id} AttachmentID=#{attachment_id}",
        hash_including(user_account_uuid: current_user.user_account_uuid, statsd: "#{document_stats_key}.success")
      )

      monitor.track_document_upload_success(form_id, attachment_id, current_user)
    end
  end

  describe '#track_document_upload_failed' do
    it 'logs a failed upload' do
      expect(StatsD).to receive(:increment).with("#{document_stats_key}.failure", tags: ["form_id:#{form_id}"])
      expect(Rails.logger).to receive(:error).with(
        "Error creating PersistentAttachment FormID=#{form_id} AttachmentID=#{attachment_id} #{error}",
        hash_including(user_account_uuid: current_user.user_account_uuid, statsd: 'api.document_upload.failure')
      )

      monitor.track_document_upload_failed(form_id, attachment_id, current_user, error)
    end
  end
end
