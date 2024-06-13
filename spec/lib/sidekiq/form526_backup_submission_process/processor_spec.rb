# frozen_string_literal: true

require 'rails_helper'

require 'evss/disability_compensation_auth_headers' # required to build a Form526Submission
require 'sidekiq/form526_backup_submission_process/submit'

RSpec.describe Sidekiq::Form526BackupSubmissionProcess::Processor do
  subject { described_class }

  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  context 'veteran with a foreign address' do
    describe 'submission and document metadata' do
      before do
        allow(Settings.form526_backup).to receive(:enabled).and_return(true)
      end

      let!(:submission) { create(:form526_submission, :with_non_us_address) }

      it 'sets the submission metadata zip code to a default value' do
        instance = subject.new(submission.id, get_upload_location_on_instantiation: false)
        expect(instance.zip).to eq('00000')
      end
    end
  end

  describe '#choose_provider' do
    let(:account) { create(:account) }
    let(:submission) { create(:form526_submission, user_uuid: account.idme_uuid, submit_endpoint: 'claims_api') }

    it 'delegates to the ApiProviderFactory with the correct data' do
      auth_headers = {}
      expect(ApiProviderFactory).to receive(:call).with(
        {
          type: ApiProviderFactory::FACTORIES[:generate_pdf],
          provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
          options: { auth_headers:, breakered: true },
          current_user: OpenStruct.new({ flipper_id: submission.user_uuid, icn: account.icn }),
          feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_GENERATE_PDF
        }
      )

      subject
        .new(submission.id, get_upload_location_on_instantiation: false)
        .choose_provider(auth_headers, ApiProviderFactory::API_PROVIDER[:lighthouse])
    end
  end
end
