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
    let(:user) { create(:user, :loa3) }
    let(:icn) { user.icn }
    let(:user_account) { create(:user_account, icn:, id: user.user_account_uuid) }
    let(:submission) { create(:form526_submission, user_account:, submit_endpoint: 'claims_api') }

    it 'delegates to the ApiProviderFactory with the correct data' do
      auth_headers = {}
      expect(ApiProviderFactory).to receive(:call).with(
        {
          type: ApiProviderFactory::FACTORIES[:generate_pdf],
          provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
          options: { auth_headers:, breakered: true },
          current_user: OpenStruct.new({ flipper_id: submission.user_uuid, icn: }),
          feature_toggle: nil
        }
      )

      subject
        .new(submission.id, get_upload_location_on_instantiation: false)
        .choose_provider(auth_headers, ApiProviderFactory::API_PROVIDER[:lighthouse])
    end

    it 'pulls from the correct Lighthouse provider according to the startedFormVersion' do
      allow_any_instance_of(LighthouseGeneratePdfProvider).to receive(:generate_526_pdf)
        .and_return(Faraday::Response.new(
                      status: 200, body: '526pdf'
                    ))

      expect(ApiProviderFactory).to receive(:call).with(
        {
          type: ApiProviderFactory::FACTORIES[:generate_pdf],
          provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
          options: { auth_headers: submission.auth_headers, breakered: true },
          current_user: OpenStruct.new({ flipper_id: submission.user_uuid, icn: }),
          feature_toggle: nil
        }
      ).and_call_original

      subject
        .new(submission.id, get_upload_location_on_instantiation: false)
        .get_form526_pdf
    end
  end

  describe '#get_form0781_pdf' do
    context 'generates a 0781 version 1 pdf' do
      let(:submission) { create(:form526_submission, :with_0781, submit_endpoint: 'benefits_intake_api') } # rubocop:disable Naming/VariableNumber

      it 'generates a 0781 v1 pdf and a 0781a pdf' do
        form0781_pdfs = subject
                        .new(submission.id, get_upload_location_on_instantiation: false)
                        .get_form0781_pdf
        expect(form0781_pdfs.count).to eq(2)
        expect(form0781_pdfs.first[:type]).to eq('21-0781')
        expect(form0781_pdfs.last[:type]).to eq('21-0781a')
      end
    end

    context 'generates a 0781 version 2 pdf' do
      let(:submission) { create(:form526_submission, :with_0781v2, submit_endpoint: 'benefits_intake_api') }

      it 'generates a 0781 v2 pdf' do
        form0781_pdfs = subject
                        .new(submission.id, get_upload_location_on_instantiation: false)
                        .get_form0781_pdf
        expect(form0781_pdfs.count).to eq(1)
        expect(form0781_pdfs.first[:type]).to eq('21-0781V2')
      end
    end
  end
end
