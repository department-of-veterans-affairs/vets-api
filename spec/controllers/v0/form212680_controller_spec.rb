# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form212680Controller, type: :controller do
  let(:form_id) { '21-2680' }
  let(:form_data) { { form: VetsJsonSchema::EXAMPLES[form_id].to_json }.to_json }

  def parsed_response
    JSON.parse(response.body)
  end

  def confirmation_number
    parsed_response.dig('data', 'attributes', 'confirmation_number')
  end

  describe 'POST #create' do
    let(:user) { create(:user, :loa3) }

    before do
      sign_in_as(user)
      allow(Flipper).to receive(:enabled?).with(:form_2680_enabled, user).and_return(true)
    end

    it 'returns expected response structure' do
      post(:create, body: form_data, as: :json)

      expect(response).to have_http_status(:ok)

      expect(parsed_response['data']['type']).to eq('saved_claims')
      expect(parsed_response['data']['attributes']['form']).to eq(form_id)
      expect(confirmation_number).to be_present
      expect(parsed_response['data']['attributes']['submitted_at']).to be_present
      expect(parsed_response['data']['attributes']['guid']).to be_present
      expect(parsed_response['data']['attributes']['regional_office']).to eq(
        [
          'Department of Veterans Affairs',
          'Pension Management Center', 'P.O. Box 5365', 'Janesville, WI 53547-5365'
        ]
      )
    end

    it 'returns a unique confirmation number for each request' do
      post(:create, body: form_data, as: :json)
      first_confirmation = confirmation_number

      post(:create, body: form_data, as: :json)
      second_confirmation = confirmation_number

      expect(first_confirmation).not_to eq(second_confirmation)
    end

    it 'returns a valid UUID as confirmation number' do
      post(:create, body: form_data, as: :json)

      expect(confirmation_number).to be_a_uuid
    end

    it 'returns ISO 8601 formatted timestamp' do
      post(:create, body: form_data, as: :json)

      submitted_at = parsed_response.dig('data', 'attributes', 'submitted_at')
      expect { DateTime.iso8601(submitted_at) }.not_to raise_error
    end

    it 'does not require authentication' do
      post(:create, body: form_data, as: :json)
      expect(response).to have_http_status(:ok)
    end

    it 'saves user_account_id on the saved claim' do
      post(:create, body: form_data, as: :json)

      saved_claim = SavedClaim::Form212680.last
      expect(saved_claim.user_account_id).not_to be_nil
      expect(saved_claim.user_account_id).to eq(user.user_account_uuid)
    end

    it 'returns bad_request when json is invalid' do
      post(:create, body: { no_form: 'missing form attribute' }.to_json, as: :json)
      expect(response).to have_http_status(:bad_request)
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_2680_enabled, anything).and_return(false)
      end

      after do
        allow(Flipper).to receive(:enabled?).with(:form_2680_enabled, anything).and_call_original
      end

      it 'returns 404 Not Found (routing error)' do
        post(:create, body: form_data, as: :json)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'InProgressForm cleanup' do
      let(:user) { create(:user, :loa3) }
      let!(:in_progress_form) { create(:in_progress_form, form_id:, user_account: user.user_account) }

      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).with(:form_2680_enabled, user).and_return(true)
      end

      it 'deletes the InProgressForm after successful submission' do
        expect do
          post(:create, body: form_data, as: :json)
        end.to change(InProgressForm, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(InProgressForm.find_by(id: in_progress_form.id)).to be_nil
      end

      it 'does not delete IPF if submission fails' do
        allow_any_instance_of(SavedClaim::Form212680).to receive(:save)
          .and_return(false)

        expect do
          post(:create, body: form_data, as: :json)
        end.not_to change(InProgressForm, :count)
      end
    end
  end

  describe 'get #download_pdf' do
    let(:user) { create(:user, :loa3) }
    let(:claim) { create(:form212680) }
    let(:temp_file_path) { "tmp/pdfs/21-2680_#{claim.id}.pdf" }

    before do
      sign_in_as(user)
      allow(Flipper).to receive(:enabled?).with(:form_2680_enabled, anything).and_return(true)
    end

    it 'generates and downloads PDF' do
      get(:download_pdf, params: { guid: claim.guid })

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/pdf')
    end

    it 'includes proper filename with UUID' do
      get(:download_pdf, params: { guid: claim.guid })

      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include('21-2680_')
      expect(response.headers['Content-Disposition']).to include('21-2680_John_Doe.pdf')
    end

    it 'deletes temporary PDF file after sending' do
      allow_any_instance_of(SavedClaim::Form212680).to receive(:generate_prefilled_pdf).and_return(temp_file_path)
      allow(File).to receive(:exist?).with(temp_file_path).and_return(true)
      allow(File).to receive(:read).with(temp_file_path).and_return('PDF content')
      expect(File).to receive(:delete).with(temp_file_path)
      get(:download_pdf, params: { guid: claim.guid })
    end

    it 'returns 500 when to_pdf returns nil' do
      allow_any_instance_of(SavedClaim::Form212680).to receive(:to_pdf).and_return(nil)
      # File.delete should not be called since source_file_path is nil
      expect(File).not_to receive(:delete)

      get(:download_pdf, params: { guid: claim.guid })
      expect(response).to have_http_status(:internal_server_error)
      expect(parsed_response['errors']).to be_present
      expect(parsed_response['errors'].first['status']).to eq('500')
    end

    it 'deletes temporary file even when file read fails' do
      allow_any_instance_of(SavedClaim::Form212680).to receive(:generate_prefilled_pdf).and_return(temp_file_path)
      allow(File).to receive(:exist?).with(temp_file_path).and_return(true)
      allow(File).to receive(:read).with(temp_file_path).and_raise(StandardError, 'Read error')
      expect(File).to receive(:delete).with(temp_file_path)

      get(:download_pdf, params: { guid: claim.guid })
      expect(response).to have_http_status(:internal_server_error)

      expect(parsed_response['errors']).to be_present
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_2680_enabled, anything).and_return(false)
      end

      it 'returns 404 Not Found (routing error)' do
        get(:download_pdf, params: { guid: claim.guid })
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'error handling' do
      it 'returns 500 for PDF generation failures' do
        allow_any_instance_of(SavedClaim::Form212680).to receive(:to_pdf).and_raise(StandardError,
                                                                                    'PDF generation error')
        get(:download_pdf, params: { guid: claim.guid })

        expect(response).to have_http_status(:internal_server_error)

        expect(parsed_response['errors']).to be_present
        expect(parsed_response['errors'].first['status']).to eq('500')
      end

      it 'returns 500 when to_pdf returns nil' do
        allow_any_instance_of(SavedClaim::Form212680).to receive(:to_pdf).and_return(nil)

        get(:download_pdf, params: { guid: claim.guid })

        expect(response).to have_http_status(:internal_server_error)

        expect(parsed_response['errors']).to be_present
        expect(parsed_response['errors'].first['status']).to eq('500')
      end
    end
  end

  describe 'POST #create without authentication' do
    it 'returns 401 when not authenticated' do
      post(:create, body: form_data, as: :json)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET #download_pdf without authentication' do
    let(:claim) { create(:form212680) }

    it 'returns 401 when not authenticated' do
      get(:download_pdf, params: { guid: claim.guid })
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
