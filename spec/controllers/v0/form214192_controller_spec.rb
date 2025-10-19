# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form214192Controller, type: :controller do
  before do
    allow(Flipper).to receive(:enabled?).with(:form_214192_enabled).and_return(true)
  end

  let(:form_data) do
    {
      veteranInformation: {
        fullName: { first: 'John', middle: 'M', last: 'Doe' },
        ssn: '123456789',
        dateOfBirth: '1980-01-01'
      },
      employmentInformation: {
        employerName: 'Acme Corporation',
        employerAddress: {
          street: '456 Business Ave',
          city: 'Commerce City',
          state: 'CA',
          postalCode: '54321'
        },
        employerEmail: 'hr@acme.com',
        employerPhone: '555-987-6543',
        typeOfWorkPerformed: 'Software Developer',
        beginningDateOfEmployment: '2015-01-15',
        endingDateOfEmployment: '2023-06-30',
        amountEarnedLast12MonthsOfEmployment: 75_000,
        timeLostLast12MonthsOfEmployment: '2 weeks',
        hoursWorkedDaily: 8,
        hoursWorkedWeekly: 40
      },
      militaryDutyStatus: {
        currentDutyStatus: 'Active Reserve',
        veteranDisabilitiesPreventMilitaryDuties: true
      },
      benefitEntitlementPayments: {
        sickRetirementOtherBenefits: false,
        typeOfBenefit: 'Retirement',
        grossMonthlyAmountOfBenefit: 1500
      }
    }
  end

  describe 'POST #create' do
    context 'with valid form data' do
      it 'creates a new claim' do
        expect do
          post :create, params: { form214192: form_data }
        end.to change(SavedClaim::Form214192, :count).by(1)
      end

      it 'returns expected response structure with success status' do
        post :create, params: { form214192: form_data }

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['data']['type']).to eq('saved_claims')
        expect(json['data']['attributes']['form']).to eq('21-4192')
        expect(json['data']['attributes']['confirmation_number']).to be_present
        expect(json['data']['attributes']['submitted_at']).to be_present
        expect(json['data']['attributes']['guid']).to be_present
        expect(json['data']['attributes']['regional_office']).to eq([])
      end

      it 'returns a unique confirmation number for each request' do
        post :create, params: { form214192: form_data }
        first_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

        post :create, params: { form214192: form_data }
        second_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

        expect(first_confirmation).not_to eq(second_confirmation)
      end

      it 'returns a valid UUID as confirmation number' do
        post :create, params: { form214192: form_data }

        json = JSON.parse(response.body)
        confirmation = json['data']['attributes']['confirmation_number']

        expect(confirmation).to be_a_uuid
      end

      it 'returns ISO 8601 formatted timestamp' do
        post :create, params: { form214192: form_data }

        json = JSON.parse(response.body)
        submitted_at = json['data']['attributes']['submitted_at']

        expect { DateTime.iso8601(submitted_at) }.not_to raise_error
      end

      it 'queues Lighthouse submission job' do
        expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async)
        post :create, params: { form214192: form_data }
      end

      it 'increments submission attempt metric' do
        expect(StatsD).to receive(:increment).with('api.form214192.submission_attempt')
        post :create, params: { form214192: form_data }
      end

      it 'logs claim submission' do
        allow(Rails.logger).to receive(:info).and_call_original
        post :create, params: { form214192: form_data }

        # Check that the logger was called with the expected message
        expect(Rails.logger).to have_received(:info).with(
          a_string_including('ClaimID=') & a_string_including('Form=21-4192')
        ).once
      end

      it 'allows unauthenticated access to create endpoint' do
        post :create, params: { form214192: form_data }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid form data' do
      it 'returns validation errors for missing required fields' do
        post :create, params: { form214192: { veteranInformation: { fullName: { first: '' } } } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors for missing veteran information' do
        invalid_data = form_data.dup
        invalid_data.delete(:veteranInformation)
        post :create, params: { form214192: invalid_data }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors for missing employment information' do
        invalid_data = form_data.dup
        invalid_data.delete(:employmentInformation)
        post :create, params: { form214192: invalid_data }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns validation errors for missing veteran SSN and VA file number' do
        invalid_data = form_data.dup
        invalid_data[:veteranInformation].delete(:ssn)
        post :create, params: { form214192: invalid_data }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'increments failure metric on validation error' do
        expect(StatsD).to receive(:increment).with('api.form214192.submission_attempt')
        expect(StatsD).to receive(:increment).with('api.form214192.failure')
        post :create, params: { form214192: { veteranInformation: { fullName: { first: '' } } } }
      end

      it 'logs error on submission failure' do
        allow(Rails.logger).to receive(:error)
        post :create, params: { form214192: { veteranInformation: { fullName: { first: '' } } } }

        expect(Rails.logger).to have_received(:error).with(
          'Form214192: error submitting claim',
          hash_including(:error)
        )
      end
    end

    context 'with missing params' do
      it 'returns error when form214192 param is missing' do
        post :create, params: {}
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST #download_pdf' do
    let(:pdf_content) { 'PDF_BINARY_CONTENT' }
    let(:temp_file_path) { '/tmp/test_pdf.pdf' }

    before do
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return(temp_file_path)
      allow(File).to receive(:read).with(temp_file_path).and_return(pdf_content)
      allow(File).to receive(:exist?).with(temp_file_path).and_return(true)
      allow(File).to receive(:delete).with(temp_file_path)
    end

    context 'with valid form data' do
      it 'generates and downloads PDF' do
        post :download_pdf, params: { form: form_data.to_json }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/pdf')
        expect(response.body).to eq(pdf_content)
      end

      it 'includes proper filename with employer name' do
        post :download_pdf, params: { form: form_data.to_json }

        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include('Acme_Corporation_21-4192')
      end

      it 'uses form number as filename when employer name is missing' do
        form_without_employer = form_data.dup
        form_without_employer[:employmentInformation].delete(:employerName)

        post :download_pdf, params: { form: form_without_employer.to_json }

        expect(response.headers['Content-Disposition']).to include('21-4192_21-4192')
      end

      it 'calls PDF filler with correct parameters' do
        expect(PdfFill::Filler).to receive(:fill_ancillary_form)
          .with(hash_including('employmentInformation' => hash_including('employerName' => 'Acme Corporation')),
                anything,
                '21-4192')
          .and_return(temp_file_path)

        post :download_pdf, params: { form: form_data.to_json }
      end

      it 'deletes temporary PDF file after sending' do
        expect(File).to receive(:delete).with(temp_file_path)
        post :download_pdf, params: { form: form_data.to_json }
      end

      it 'deletes temporary file even when error occurs' do
        allow(File).to receive(:read).with(temp_file_path).and_raise(StandardError, 'Read error')
        expect(File).to receive(:delete).with(temp_file_path)

        post :download_pdf, params: { form: form_data.to_json }
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'allows unauthenticated access to download_pdf endpoint' do
        post :download_pdf, params: { form: form_data.to_json }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid JSON' do
      it 'raises error for invalid JSON' do
        post :download_pdf, params: { form: 'invalid json' }
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'when PDF generation fails' do
      it 'raises error when PDF filler fails' do
        allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError, 'PDF generation failed')
        allow(File).to receive(:exist?).and_return(true)

        post :download_pdf, params: { form: form_data.to_json }
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'feature flag' do
    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_214192_enabled).and_return(false)
      end

      it 'returns 404 for create endpoint' do
        post :create, params: { form214192: form_data }
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for download_pdf endpoint' do
        post :download_pdf, params: { form: form_data.to_json }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when feature flag is enabled' do
      it 'allows access to create endpoint' do
        post :create, params: { form214192: form_data }
        expect(response).to have_http_status(:ok)
      end

      it 'allows access to download_pdf endpoint' do
        post :download_pdf, params: { form: form_data.to_json }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
