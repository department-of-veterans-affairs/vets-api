# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::CentralMailStatus, type: :concern do
  context 'when verifying model status structures' do
    let(:local_statuses) { subject::STATUSES }

    it 'fails if one or more CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES keys or values is mismatched' do
      status_hashes = subject::CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.values
      status_attr_keys = status_hashes.map(&:keys).flatten
      status_attr_values = status_hashes.map { |attr| attr[:status] }.uniq

      expect(local_statuses).to include(*status_attr_values)
      expect(status_attr_keys).not_to include(*status_attr_values)
    end

    it 'fails if error statuses are mismatched' do
      central_mail_statuses = subject::CENTRAL_MAIL_STATUS_TO_APPEAL_ATTRIBUTES.keys
      error_statuses = subject::CENTRAL_MAIL_ERROR_STATUSES

      expect(central_mail_statuses).to include(*error_statuses)
    end

    it 'fails if remaining statuses are mismatched' do
      additional_statuses = [*subject::RECEIVED_OR_PROCESSING, *subject::COMPLETE_STATUSES]

      expect(local_statuses).to include(*additional_statuses)
    end
  end
end
