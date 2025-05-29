# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/stub_financial_status_report'
require_relative '../../../support/financial_status_report_helpers'

RSpec.describe 'DebtsApi::V0::FinancialStatusReports', type: :request do
  let(:fsr_service) { DebtsApi::V0::FinancialStatusReportService }
  let(:full_transform_service) { DebtsApi::V0::FsrFormTransform::FullTransformService }
  let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
  let(:user) { build(:user, :loa3, :with_terms_of_use_agreement) }
  let(:filenet_id) { '93631483-E9F9-44AA-BB55-3552376400D8' }

  before do
    sign_in_as(user)
    mock_pdf_fill
    allow(StatsD).to receive(:increment).and_call_original
  end

  def mock_pdf_fill
    pdf_stub = class_double(PdfFill::Filler).as_stubbed_const
    allow(pdf_stub).to receive(:fill_ancillary_form).and_return(Rails.root.join(*'/spec/fixtures/dmc/5655.pdf'
                                                                                   .split('/')).to_s)
  end

  describe '#create' do
    context 'when service raises FSRNotFoundInRedis' do
      before do
        expect_any_instance_of(fsr_service).to receive(
          :submit_financial_status_report
        ).and_raise(
          fsr_service::FSRNotFoundInRedis
        )
      end

      it 'renders 404' do
        post('/debts_api/v0/financial_status_reports', params: valid_form_data)
        expect(response).to have_http_status(:not_found)
        expect(response.header['Content-Type']).to include('application/json')
        expect(JSON.parse(response.body)).to be_nil
      end
    end

    it 'submits a financial status report' do
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          post('/debts_api/v0/financial_status_reports', params: valid_form_data.to_h, as: :json)
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe '#transform_and_submit' do
    let(:pre_transform_fsr_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/pre_transform')
    end

    let(:pre_transform_fsr_streamlined_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/sw_short/streamlined_pre_transform')
    end

    let(:pre_transform_fsr_streamlined_long_form_data) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/sw_short/streamlined_long_pre_transform')
    end

    context 'when service raises a standard error' do
      let(:post_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
      end

      before do
        allow(DebtsApi::V0::FsrFormTransform::FullTransformService).to receive(:new)
          .and_raise(StandardError.new('Simulated error'))
      end

      it 'renders 500' do
        expect(StatsD).to receive(:increment).once.with('api.fsr_submission.full_transform.error')
        post(
          '/debts_api/v0/financial_status_reports/transform_and_submit',
          params: pre_transform_fsr_form_data.to_h,
          as: :json
        )
        expect(response).to have_http_status(:internal_server_error)
        expect(response.header['Content-Type']).to include('application/json')
        expect(response.body).not_to be_nil
      end
    end

    context 'when service raises FSRNotFoundInRedis' do
      let(:post_transform_fsr_form_data) do
        get_fixture_absolute('modules/debts_api/spec/fixtures/pre_submission_fsr/post_transform')
      end

      before do
        expect_any_instance_of(fsr_service).to receive(
          :submit_financial_status_report
        ).and_raise(fsr_service::FSRNotFoundInRedis)
      end

      it 'renders 404' do
        post(
          '/debts_api/v0/financial_status_reports/transform_and_submit',
          params: pre_transform_fsr_form_data.to_h,
          as: :json
        )
        expect(response).to have_http_status(:not_found)
        expect(response.header['Content-Type']).to include('application/json')
        expect(JSON.parse(response.body)).to be_nil
      end
    end

    it 'submits a financial status report' do
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          expect(StatsD).to receive(:increment).once.with('api.fsr_submission.full_transform.run')
          post(
            '/debts_api/v0/financial_status_reports/transform_and_submit',
            params: pre_transform_fsr_streamlined_form_data.to_h,
            as: :json
          )
          expect(response).to have_http_status(:ok)
        end
      end
    end

    it 'submits a streamlined short form' do
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          expect(StatsD).to receive(:increment).once.with('api.fsr_submission.full_transform.run')
          post(
            '/debts_api/v0/financial_status_reports/transform_and_submit',
            params: pre_transform_fsr_form_data.to_h,
            as: :json
          )
          expect(response).to have_http_status(:ok)
        end
      end
    end

    it 'submits a streamlined long form' do
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          expect(StatsD).to receive(:increment).once.with('api.fsr_submission.full_transform.run')
          post(
            '/debts_api/v0/financial_status_reports/transform_and_submit',
            params: pre_transform_fsr_streamlined_long_form_data.to_h,
            as: :json
          )
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe '#download_pdf' do
    stub_financial_status_report(:download_pdf)

    it 'downloads the filled financial status report pdf' do
      set_filenet_id(user:, filenet_id:)
      get '/debts_api/v0/financial_status_reports/download_pdf'
      expect(response.header['Content-Type']).to eq('application/pdf')
      expect(response.body).to eq(content)
    end
  end

  describe '#rehydrate' do
    context 'on a nonexistent submission' do
      it 'renders a 404' do
        get '/debts_api/v0/financial_status_reports/rehydrate_submission/1'
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'on a submission you don\'t own' do
      let(:form5655_submission) { create(:debts_api_form5655_submission) }

      it 'renders a 404' do
        form5655_submission
        form5655_submission.update!(user_uuid: 'nottherightguy', ipf_data: '{"its":"me"}')
        get "/debts_api/v0/financial_status_reports/rehydrate_submission/#{form5655_submission.id}"
        expect(response).to have_http_status(:unauthorized)
        body = "{\"error\":\"User #{user.uuid} does not own submission #{form5655_submission.id}\"}"
        expect(response.body).to eq(body)
      end
    end

    context 'on a submission you do own' do
      let(:form5655_submission) do
        create(:debts_api_form5655_submission, user_uuid: 'b2fab2b56af045e1a9e2394347af91ef')
      end

      it 'rehydrates In Progress Form' do
        form5655_submission
        form5655_submission.update!(user_uuid: user.uuid, ipf_data: '{"its":"me"}')
        get "/debts_api/v0/financial_status_reports/rehydrate_submission/#{form5655_submission.id}"
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#submissions' do
    it 'returns all Financial Status Report submissions for the current user' do
      get '/debts_api/v0/financial_status_reports/submissions'

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('submissions')
    end

    context 'when user has no submissions' do
      it 'returns an empty array' do
        get '/debts_api/v0/financial_status_reports/submissions'

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['submissions']).to eq([])
      end
    end

    context 'when user has submissions' do
      let!(:submission1) do
        create(:debts_api_form5655_submission,
               user_uuid: user.uuid,
               user_account: user.user_account,
               created_at: 1.day.ago,
               state: 'submitted',
               public_metadata: {
                 'debt_type' => 'DEBT',
                 'streamlined' => { 'value' => true, 'type' => 'short' },
                 'combined' => false
               })
      end

      let!(:submission2) do
        create(:debts_api_form5655_submission,
               user_uuid: user.uuid,
               user_account: user.user_account,
               created_at: 3.days.ago,
               state: 'failed',
               public_metadata: {
                 'debt_type' => 'COPAY',
                 'streamlined' => { 'value' => false },
                 'combined' => true
               })
      end

      let!(:other_user_submission) do
        create(:debts_api_form5655_submission,
               user_uuid: 'other-user-uuid',
               user_account: create(:user_account),
               state: 'submitted')
      end

      it 'returns submissions for the current user ordered by most recent' do
        get '/debts_api/v0/financial_status_reports/submissions'

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['submissions'].length).to eq(2)

        first_submission = json_response['submissions'][0]
        second_submission = json_response['submissions'][1]
        expect(first_submission['id']).to eq(submission1.id)
        expect(second_submission['id']).to eq(submission2.id)
      end

      it 'returns the correct data structure for each submission' do
        get '/debts_api/v0/financial_status_reports/submissions'

        json_response = JSON.parse(response.body)
        first_submission = json_response['submissions'][0]

        expect(first_submission['id']).to eq(submission1.id)
        expect(first_submission['created_at']).to eq(submission1.created_at.as_json)
        expect(first_submission['updated_at']).to eq(submission1.updated_at.as_json)
        expect(first_submission['state']).to eq('submitted')

        expect(first_submission['metadata']['debt_type']).to eq('DEBT')
        expect(first_submission['metadata']['streamlined']).to eq({ 'value' => true, 'type' => 'short' })
        expect(first_submission['metadata']['combined']).to be(false)
      end

      it 'handles nil public_metadata gracefully' do
        submission1.update!(public_metadata: nil)

        get '/debts_api/v0/financial_status_reports/submissions'

        json_response = JSON.parse(response.body)
        first_submission = json_response['submissions'][0]

        expect(first_submission['metadata']['debt_type']).to be_nil
        expect(first_submission['metadata']['streamlined']).to be_nil
        expect(first_submission['metadata']['combined']).to be_nil
      end

      it 'maintains backwards compatibility with id field' do
        get '/debts_api/v0/financial_status_reports/submissions'

        json_response = JSON.parse(response.body)
        first_submission = json_response['submissions'][0]

        expect(first_submission.keys.first).to eq('id')
      end

      it 'handles missing or nil fields without errors' do
        create(:debts_api_form5655_submission,
               user_uuid: user.uuid,
               user_account: user.user_account,
               state: nil,
               public_metadata: nil)

        submission1.destroy!
        submission2.destroy!

        get '/debts_api/v0/financial_status_reports/submissions'

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['submissions'].length).to eq(1)
        submission_data = json_response['submissions'][0]

        expect(submission_data['state']).to be_nil
        expect(submission_data['metadata']['debt_type']).to be_nil
        expect(submission_data['metadata']['streamlined']).to be_nil
        expect(submission_data['metadata']['combined']).to be_nil
      end
    end

    context 'when submissions have debt identifiers' do
      let!(:vba_submission) do
        create(:debts_api_form5655_submission,
               user_uuid: user.uuid,
               user_account: user.user_account,
               state: 'submitted',
               public_metadata: {
                 'debt_type' => 'DEBT',
                 'streamlined' => { 'value' => false },
                 'combined' => false
               },
               metadata: {
                 'debts' => [
                   {
                     'deductionCode' => '30',
                     'fileNumber' => '123456789',
                     'payeeNumber' => '00',
                     'originalAR' => '1000.00',
                     'currentAR' => '800.00',
                     'debtType' => 'DEBT'
                   },
                   {
                     'deductionCode' => '41',
                     'fileNumber' => '123456789',
                     'payeeNumber' => '01',
                     'originalAR' => '500.00',
                     'currentAR' => '500.00',
                     'debtType' => 'DEBT'
                   }
                 ]
               }.to_json)
      end

      let!(:vha_submission) do
        create(:debts_api_form5655_submission,
               user_uuid: user.uuid,
               user_account: user.user_account,
               state: 'submitted',
               public_metadata: {
                 'debt_type' => 'COPAY',
                 'streamlined' => { 'value' => false },
                 'combined' => false
               },
               metadata: {
                 'copays' => [
                   {
                     'id' => '3fa85f64-5717-4562-b3fc-2c963f66afa6',
                     'pSFacilityNum' => '757',
                     'pSStatementVal' => '0000037953E',
                     'pHAmtDue' => '107.24',
                     'debtType' => 'COPAY'
                   }
                 ]
               }.to_json)
      end

      it 'includes debt identifiers for VBA debts' do
        get '/debts_api/v0/financial_status_reports/submissions'

        json_response = JSON.parse(response.body)
        vba_submission_data = json_response['submissions'].find { |s| s['id'] == vba_submission.id }

        expect(vba_submission_data['metadata']['debt_identifiers']).to contain_exactly('301000', '41500')
      end

      it 'includes debt identifiers for VHA copays' do
        get '/debts_api/v0/financial_status_reports/submissions'

        json_response = JSON.parse(response.body)
        vha_submission_data = json_response['submissions'].find { |s| s['id'] == vha_submission.id }

        expect(vha_submission_data['metadata']['debt_identifiers']).to contain_exactly(
          '3fa85f64-5717-4562-b3fc-2c963f66afa6'
        )
      end

      it 'returns empty array when metadata parsing fails' do
        vba_submission.update!(metadata: 'invalid json')

        get '/debts_api/v0/financial_status_reports/submissions'

        json_response = JSON.parse(response.body)
        submission_data = json_response['submissions'].find { |s| s['id'] == vba_submission.id }

        expect(submission_data['metadata']['debt_identifiers']).to eq([])
      end
    end
  end
end
