# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::MyVA::SubmissionStatusesController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:user_account) { user.user_account }

  before do
    sign_in_as(user)
  end

  describe 'GET #show' do
    context 'when both feature flags are disabled' do
      let(:empty_report) do
        double('Report', submission_statuses: [], errors: [])
      end

      before do
        allow(Flipper).to receive(:enabled?)
                      .with(:my_va_display_all_lighthouse_benefits_intake_forms, user).and_return(false)
        allow(Flipper).to receive(:enabled?)
                      .with(:my_va_display_decision_reviews_forms, user).and_return(false)
        allow(Forms::SubmissionStatuses::Report).to receive(:new).and_return(empty_report)
        allow(empty_report).to receive(:run).and_return(empty_report)
      end

      it 'returns empty array when no forms are allowed' do
        get :show

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']).to eq([])
      end
    end

    context 'when benefits intake flag is enabled but decision reviews is disabled' do
      let(:benefits_report) do
        double('Report', submission_statuses: [], errors: [])
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:my_va_display_all_lighthouse_benefits_intake_forms,
                                                  user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:my_va_display_decision_reviews_forms, user).and_return(false)
      end

      it 'creates report with only benefits intake enabled' do
        allow(Forms::SubmissionStatuses::Report).to receive(:new).and_return(benefits_report)
        allow(benefits_report).to receive(:run).and_return(benefits_report)

        get :show

        expect(response).to have_http_status(:ok)

        # Verify the report was created and run
        expect(Forms::SubmissionStatuses::Report).to have_received(:new)
        expect(benefits_report).to have_received(:run)
      end
    end

    context 'when decision reviews flag is enabled but benefits intake is disabled' do
      let(:decision_reviews_report) do
        double('Report', submission_statuses: [], errors: [])
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:my_va_display_all_lighthouse_benefits_intake_forms,
                                                  user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:my_va_display_decision_reviews_forms, user).and_return(true)
      end

      it 'creates report with only decision reviews enabled' do
        allow(Forms::SubmissionStatuses::Report).to receive(:new).and_return(decision_reviews_report)
        allow(decision_reviews_report).to receive(:run).and_return(decision_reviews_report)

        get :show

        expect(response).to have_http_status(:ok)

        # Verify the report was created and run
        expect(Forms::SubmissionStatuses::Report).to have_received(:new)
        expect(decision_reviews_report).to have_received(:run)
      end
    end

    context 'when both feature flags are enabled' do
      let(:combined_report) do
        double(
          'Report',
          submission_statuses: [
            OpenStruct.new(
              id: '123',
              form_type: '21-4142',
              status: 'received',
              message: 'Form received',
              detail: 'Processing started',
              updated_at: 1.day.ago,
              created_at: 2.days.ago,
              pdf_support: true
            )
          ],
          errors: []
        )
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:my_va_display_all_lighthouse_benefits_intake_forms,
                                                  user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:my_va_display_decision_reviews_forms, user).and_return(true)
      end

      it 'creates report with both gateways enabled and all form types' do
        allow(Forms::SubmissionStatuses::Report).to receive(:new).and_return(combined_report)
        allow(combined_report).to receive(:run).and_return(combined_report)

        get :show

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].length).to eq(1)

        form_data = json_response['data'].first
        expect(form_data['id']).to eq('123')
        expect(form_data['attributes']['form_type']).to eq('21-4142')
        expect(form_data['attributes']['status']).to eq('received')
        expect(form_data['attributes']['pdf_support']).to be true

        # Verify the report was created and run
        expect(Forms::SubmissionStatuses::Report).to have_received(:new)
        expect(combined_report).to have_received(:run)
      end
    end

    context 'when report execution fails' do
      let(:failing_report) do
        double('Report')
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:my_va_display_all_lighthouse_benefits_intake_forms,
                                                  user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:my_va_display_decision_reviews_forms, user).and_return(false)
        allow(Forms::SubmissionStatuses::Report).to receive(:new).and_return(failing_report)
        allow(failing_report).to receive(:run).and_raise(StandardError, 'Service unavailable')
      end

      it 'handles errors gracefully' do
        # Check if the controller catches and handles the error
        get :show

        # If it doesn't raise an error, it should return a 500 status
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'serialization' do
      let(:mock_submission_status) do
        OpenStruct.new(
          id: 'test-guid-123',
          form_type: '21-4142',
          status: 'processing',
          message: 'Your form is being processed',
          detail: 'Expected completion in 5-7 business days',
          updated_at: Time.zone.parse('2024-01-15T10:30:00Z'),
          created_at: Time.zone.parse('2024-01-10T09:00:00Z'),
          pdf_support: true
        )
      end

      let(:serialization_report) do
        double(
          'Report',
          submission_statuses: [mock_submission_status],
          errors: []
        )
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:my_va_display_all_lighthouse_benefits_intake_forms,
                                                  user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:my_va_display_decision_reviews_forms, user).and_return(false)
        allow(Forms::SubmissionStatuses::Report).to receive(:new).and_return(serialization_report)
        allow(serialization_report).to receive(:run).and_return(serialization_report)
      end

      it 'serializes submission status data correctly' do
        get :show

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response['data']).to be_an(Array)
        expect(json_response['data'].length).to eq(1)

        serialized_status = json_response['data'].first
        expect(serialized_status['id']).to eq('test-guid-123')
        expect(serialized_status['type']).to eq('submission_status')

        attributes = serialized_status['attributes']
        expect(attributes['form_type']).to eq('21-4142')
        expect(attributes['status']).to eq('processing')
        expect(attributes['message']).to eq('Your form is being processed')
        expect(attributes['detail']).to eq('Expected completion in 5-7 business days')
        expect(attributes['pdf_support']).to be true
        expect(attributes['updated_at']).to eq('2024-01-15T10:30:00.000Z')
        expect(attributes['created_at']).to eq('2024-01-10T09:00:00.000Z')
      end
    end
  end
end
