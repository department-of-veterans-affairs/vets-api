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
        form_uuid = '12345678-1234-5678-1234-567812345678'
        different_uuid = '87654321-4321-8765-4321-876543210987'

        # Create main form and supporting documents for this form
        [
          "#{form_uuid}_vha_10_10d.pdf",
          "#{form_uuid}_supporting_doc_1.pdf",
          "#{form_uuid}_supporting_doc_2.pdf"
        ].each do |filename|
          IvcChampvaForm.create!(
            form_uuid:,
            email: 'test@email.com',
            first_name: 'Veteran',
            last_name: 'Surname',
            form_number: '10-10D',
            file_name: filename,
            s3_status: 'Submitted',
            pega_status: nil,
            case_id: nil,
            email_sent: false
          )
        end

        # Create an unrelated supporting document with a different form_uuid
        IvcChampvaForm.create!(
          form_uuid: different_uuid,
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: "#{different_uuid}_supporting_doc_1.pdf",
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        # Send payload with multiple files to update
        payload = {
          'form_uuid' => form_uuid,
          'file_names' => [
            "#{form_uuid}_vha_10_10d.pdf",
            "#{form_uuid}_supporting_doc_1.pdf"
          ],
          'case_id' => 'ABC-1234',
          'status' => 'Processed'
        }

        post '/ivc_champva/v1/forms/status_updates', params: payload

        # Verify only the specified files were updated
        updated_forms = IvcChampvaForm.where(form_uuid:, pega_status: 'Processed')
        expect(updated_forms.count).to eq(2)
        expect(updated_forms.pluck(:file_name).sort).to eq([
          "#{form_uuid}_vha_10_10d.pdf",
          "#{form_uuid}_supporting_doc_1.pdf"
        ].sort)

        # Verify other documents were not updated
        non_updated_forms = IvcChampvaForm.where(pega_status: nil)
        expect(non_updated_forms.count).to eq(2)
        expect(non_updated_forms.pluck(:file_name).sort).to eq([
          "#{form_uuid}_supporting_doc_2.pdf",
          "#{different_uuid}_supporting_doc_1.pdf"
        ].sort)

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

    context 'with merged PDF submission' do
      let(:form_uuid) { '12345678-1234-5678-1234-567812345678' }
      let(:merged_pdf_payload) do
        {
          'form_uuid' => form_uuid,
          'file_names' => ["#{form_uuid}_merged.pdf"],
          'case_id' => 'ABC-1234',
          'status' => 'Processed'
        }
      end

      before do
        allow_any_instance_of(IvcChampva::Email).to receive(:valid_environment?).and_return(true)
        IvcChampvaForm.delete_all
      end

      it 'updates both merged PDF and supporting documents with same status' do
        # Create merged PDF record
        IvcChampvaForm.create!(
          form_uuid:,
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: "#{form_uuid}_merged.pdf",
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        # Create supporting document records
        ['supporting_doc_1.pdf', 'supporting_doc_2.pdf'].each do |doc|
          IvcChampvaForm.create!(
            form_uuid:,
            email: 'test@email.com',
            first_name: 'Veteran',
            last_name: 'Surname',
            form_number: '10-10D',
            file_name: "#{form_uuid}_#{doc}",
            s3_status: 'Submitted',
            pega_status: nil,
            case_id: nil,
            email_sent: false
          )
        end

        post '/ivc_champva/v1/forms/status_updates', params: merged_pdf_payload

        # Verify all records were updated
        updated_forms = IvcChampvaForm.where(form_uuid:)
        expect(updated_forms.count).to eq(3)
        expect(updated_forms.pluck(:pega_status).uniq).to eq(['Processed'])
        expect(updated_forms.pluck(:case_id).uniq).to eq(['ABC-1234'])
        expect(response).to have_http_status(:ok)
      end

      it 'sends confirmation email only once when processing merged PDF' do
        email_instance = instance_double(IvcChampva::Email)
        allow(IvcChampva::Email).to receive(:new).and_return(email_instance)
        allow(email_instance).to receive(:send_email).and_return(true)

        # Create merged PDF and supporting docs
        IvcChampvaForm.create!(
          form_uuid:,
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: "#{form_uuid}_merged.pdf",
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        ['supporting_doc_1.pdf', 'supporting_doc_2.pdf'].each do |doc|
          IvcChampvaForm.create!(
            form_uuid:,
            email: 'test@email.com',
            first_name: 'Veteran',
            last_name: 'Surname',
            form_number: '10-10D',
            file_name: "#{form_uuid}_#{doc}",
            s3_status: 'Submitted',
            pega_status: nil,
            case_id: nil,
            email_sent: false
          )
        end

        post '/ivc_champva/v1/forms/status_updates', params: merged_pdf_payload

        # Verify email was sent exactly once
        expect(email_instance).to have_received(:send_email).once

        # Verify all records were marked as email_sent
        updated_forms = IvcChampvaForm.where(form_uuid:)
        expect(updated_forms.pluck(:email_sent).uniq).to eq([true])
      end

      it 'handles Not Processed status for merged PDF submissions without sending email' do
        email_instance = instance_double(IvcChampva::Email)
        allow(IvcChampva::Email).to receive(:new).and_return(email_instance)
        allow(email_instance).to receive(:send_email).and_return(true)

        # Create merged PDF and supporting docs
        IvcChampvaForm.create!(
          form_uuid:,
          email: 'test@email.com',
          first_name: 'Veteran',
          last_name: 'Surname',
          form_number: '10-10D',
          file_name: "#{form_uuid}_merged.pdf",
          s3_status: 'Submitted',
          pega_status: nil,
          case_id: nil,
          email_sent: false
        )

        ['supporting_doc_1.pdf', 'supporting_doc_2.pdf'].each do |doc|
          IvcChampvaForm.create!(
            form_uuid:,
            email: 'test@email.com',
            first_name: 'Veteran',
            last_name: 'Surname',
            form_number: '10-10D',
            file_name: "#{form_uuid}_#{doc}",
            s3_status: 'Submitted',
            pega_status: nil,
            case_id: nil,
            email_sent: false
          )
        end

        not_processed_payload = merged_pdf_payload.merge('status' => 'Not Processed')

        post '/ivc_champva/v1/forms/status_updates', params: not_processed_payload

        # Verify email was not sent
        expect(email_instance).not_to have_received(:send_email)

        # Verify all records were updated with Not Processed status
        updated_forms = IvcChampvaForm.where(form_uuid:)
        expect(updated_forms.pluck(:pega_status).uniq).to eq(['Not Processed'])
        expect(updated_forms.pluck(:email_sent).uniq).to eq([false])
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
