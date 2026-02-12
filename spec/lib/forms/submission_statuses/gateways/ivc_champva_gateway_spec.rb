# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateways/ivc_champva_gateway'

RSpec.describe Forms::SubmissionStatuses::Gateways::IvcChampvaGateway do
  subject(:gateway) { described_class.new(user_account:, allowed_forms:) }

  let(:user_account) { create(:user_account) }
  let(:allowed_forms) { ['10-10D'] }
  let(:email) { 'vets.gov.user+status@gmail.com' }

  before do
    verification = create(:user_verification, user_account:)
    verification.user_credential_email.update!(credential_email: email)
  end

  describe '#data' do
    it 'returns normalized submissions and statuses for the user email' do
      form_uuid = SecureRandom.uuid
      create(
        :ivc_champva_form,
        email: " #{email.upcase} ",
        form_uuid:,
        form_number: '10-10D',
        pega_status: 'Processed',
        created_at: 2.days.ago,
        updated_at: 1.day.ago
      )

      data = gateway.data

      expect(data.submissions.size).to eq(1)
      expect(data.submissions.first.id).to eq(form_uuid)
      expect(data.submissions.first.form_type).to eq('10-10D')

      status = data.intake_statuses.first['attributes']
      expect(status['guid']).to eq(form_uuid)
      expect(status['status']).to eq('vbms')
      expect(status['message']).to eq('Form received')
    end

    it 'filters out forms not in allowed_forms' do
      create(
        :ivc_champva_form,
        email:,
        form_uuid: SecureRandom.uuid,
        form_number: '10-7959A',
        pega_status: 'Processed'
      )

      data = gateway.data

      expect(data.submissions).to eq([])
      expect(data.intake_statuses).to be_nil
    end
  end
end
