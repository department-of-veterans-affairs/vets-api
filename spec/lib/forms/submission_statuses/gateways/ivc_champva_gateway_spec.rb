# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/dataset'
require 'forms/submission_statuses/error_handler'
require 'forms/submission_statuses/gateways/ivc_champva_gateway'

describe Forms::SubmissionStatuses::Gateways::IvcChampvaGateway,
         feature: :form_submission,
         team_owner: :health_apps_backend do
  let(:user_account) { create(:user_account) }

  describe '#submissions' do
    it 'returns only records matching the provided user email' do
      create(:ivc_champva_form, email: 'test@example.com', form_uuid: SecureRandom.uuid)
      create(:ivc_champva_form, email: 'other@example.com', form_uuid: SecureRandom.uuid)

      gateway = described_class.new(user_account:, user_email: 'test@example.com')

      expect(gateway.submissions.length).to eq(1)
      expect(gateway.submissions.first.email).to eq('test@example.com')
    end

    it 'returns empty list when user email is missing' do
      gateway = described_class.new(user_account:, user_email: nil)
      allow(Rails.logger).to receive(:info)

      expect(gateway.submissions).to eq([])
      expect(Rails.logger).to have_received(:info).with(
        'Skipping IVC CHAMPVA submission status lookup due to missing user email',
        hash_including(service: 'ivc_champva')
      )
    end
  end

  describe '#api_statuses' do
    it 'returns nil statuses and nil errors' do
      gateway = described_class.new(user_account:, user_email: 'test@example.com')

      expect(gateway.api_statuses([])).to eq([nil, nil])
    end
  end
end
