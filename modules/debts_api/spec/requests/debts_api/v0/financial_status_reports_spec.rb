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
end
