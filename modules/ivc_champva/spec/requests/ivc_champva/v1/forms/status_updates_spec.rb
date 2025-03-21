# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IvcChampva::V1::Forms::StatusUpdates', type: :request do
  before do
    allow_any_instance_of(IvcChampva::V1::PegaController).to receive(:authenticate_service_account).and_return(true)
  end

  describe 'POST #update_status' do
    let(:valid_payload) do
      {
        form_uuid: '12345678-1234-5678-1234-567812345678',
        file_names: ['12345678-1234-5678-1234-567812345678_vha_10_10d.pdf',
                     '12345678-1234-5678-1234-567812345678_vha_10_10d1.pdf'],
        case_id: 'ABC-1234',
        status: 'Processed'
      }
    end

    context 'with valid payload' do
      before do
        allow_any_instance_of(IvcChampva::Email).to receive(:valid_environment?).and_return(true)
      end

      it 'returns HTTP status 200 with same form_uuid but not all files' do
        IvcChampvaForm.delete_all
        IvcChampvaForm.create!(
          form_uuid: '12345678-1234-5678-1234-567812345678',
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: '12345678-1234-5678-1234-567812345678_vha_10_10d.pdf',
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        IvcChampvaForm.create!(
          form_uuid: '12345678-1234-5678-1234-567812345678',
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: '12345678-1234-5678-1234-567812345678_vha_10_10d1.pdf',
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        IvcChampvaForm.create!(
          form_uuid: '12345678-1234-5678-1234-567812345678',
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: '12345678-1234-5678-1234-567812345678_vha_10_10d2.pdf',
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        post '/ivc_champva/v1/forms/status_updates', params: valid_payload

        ivc_forms = [IvcChampvaForm.all]
        status_array = ivc_forms.map { |form| form.pluck(:pega_status) }
        case_id_array = ivc_forms.map { |form| form.pluck(:case_id) }
        email_sent_array = ivc_forms.map { |form| form.pluck(:email_sent) }

        # only 2/3 should be updated
        expect(status_array.flatten.compact!).to eq(%w[Processed Processed])
        expect(case_id_array.flatten.compact!).to eq(%w[ABC-1234 ABC-1234])
        expect(email_sent_array.flatten).to eq([true, true, true])
        expect(response).to have_http_status(:ok)
      end

      it 'returns HTTP status 200 with different form_uuid' do
        IvcChampvaForm.delete_all
        IvcChampvaForm.create!(
          form_uuid: 'd8f2902b-0b6e-4b8e-88d4-5f7a4a5b7f6d',
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: 'd8f2902b-0b6e-4b8e-88d4-5f7a4a5b7f6d_vha_10_10d.pdf',
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        IvcChampvaForm.create!(
          form_uuid: '12345678-1234-5678-1234-567812345678',
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: '12345678-1234-5678-1234-567812345678_vha_10_10d.pdf',
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        post '/ivc_champva/v1/forms/status_updates', params: valid_payload

        ivc_forms = [IvcChampvaForm.all]
        status_array = ivc_forms.map { |form| form.pluck(:pega_status) }
        case_id_array = ivc_forms.map { |form| form.pluck(:case_id) }
        email_sent_array = ivc_forms.map { |form| form.pluck(:email_sent) }

        ordered_email_sent_array = email_sent_array.flatten.sort_by { |b| b ? 1 : 0 }

        expect(status_array.flatten.compact!).to eq(['Processed'])
        expect(case_id_array.flatten.compact!).to eq(['ABC-1234'])
        expect(ordered_email_sent_array).to eq([false, true])
        expect(response).to have_http_status(:ok)
      end

      it 'returns HTTP status 200 but does not attempt email send' do
        IvcChampvaForm.delete_all
        created_row =
          IvcChampvaForm.create!(
            form_uuid: '12345678-1234-5678-1234-567812345678',
            email: 'test@email.com',
            first_name: 'Veteran',
            last_name: 'Surname',
            form_number: '10-10D',
            file_name: '12345678-1234-5678-1234-567812345678_vha_10_10d.pdf',
            s3_status: 'Submitted',
            pega_status: 'Processed',
            case_id: 'ABC-1234',
            email_sent: true
          )

        post '/ivc_champva/v1/forms/status_updates', params: valid_payload

        maybe_updated_form = IvcChampvaForm.first

        expect(created_row.attributes).to eq(maybe_updated_form.attributes)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with valid payload and status of Not Processed' do
      let(:valid_payload_with_status_of_not_processed) do
        {
          form_uuid: '12345678-1234-5678-1234-567812345678',
          file_names: ['12345678-1234-5678-1234-567812345678_vha_10_10d.pdf',
                       '12345678-1234-5678-1234-567812345678_vha_10_10d1.pdf'],
          case_id: 'ABC-1234',
          status: 'Not Processed'
        }
      end

      let(:email_instance) { instance_double(IvcChampva::Email) }

      before do
        allow_any_instance_of(IvcChampva::Email).to receive(:valid_environment?).and_return(true)
        allow(IvcChampva::Email).to receive(:new).and_return(email_instance)
        allow(email_instance).to receive(:send_email).and_return(true)
      end

      it 'returns HTTP status 200 with same form_uuid but not all files and sends no email' do
        IvcChampvaForm.delete_all
        IvcChampvaForm.create!(
          form_uuid: '12345678-1234-5678-1234-567812345678',
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: '12345678-1234-5678-1234-567812345678_vha_10_10d.pdf',
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        IvcChampvaForm.create!(
          form_uuid: '12345678-1234-5678-1234-567812345678',
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: '12345678-1234-5678-1234-567812345678_vha_10_10d1.pdf',
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        IvcChampvaForm.create!(
          form_uuid: '12345678-1234-5678-1234-567812345678',
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: '12345678-1234-5678-1234-567812345678_vha_10_10d2.pdf',
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        post '/ivc_champva/v1/forms/status_updates', params: valid_payload_with_status_of_not_processed

        # an email should not be sent
        expect(email_instance).not_to have_received(:send_email)

        ivc_forms = [IvcChampvaForm.all]
        status_array = ivc_forms.map { |form| form.pluck(:pega_status) }
        case_id_array = ivc_forms.map { |form| form.pluck(:case_id) }
        email_sent_array = ivc_forms.map { |form| form.pluck(:email_sent) }

        # only 2/3 should be updated
        expect(status_array.flatten.compact!).to eq(['Not Processed', 'Not Processed'])
        expect(case_id_array.flatten.compact!).to eq(%w[ABC-1234 ABC-1234])
        expect(email_sent_array.flatten).to eq([false, false, false])
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid payload' do
      let(:invalid_payload) { { status: 'invalid' } }

      it 'returns HTTP status 200' do
        post '/ivc_champva/v1/forms/status_updates', params: invalid_payload
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns an error message' do
        post '/ivc_champva/v1/forms/status_updates', params: invalid_payload
        expect(response.body).to include('error')
      end
    end
  end
end
