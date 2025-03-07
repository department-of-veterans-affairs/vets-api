# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::ProdSupportUtilities::MissingStatusCleanup do
  subject = TestClass.new

  describe 'batch records' do
    subject = IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new

    it 'returns a forms batched by form_uuid' do
      IvcChampvaForm.delete_all
      IvcChampvaForm.create!(
        form_uuid: '12345678-1234-5678-1234-567812345678',
        email: 'veteran@email.com',
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
        email: 'veteran@email.com',
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
        form_uuid: 'a2345678-1234-5678-1234-567812345678',
        email: 'applicant@email.com',
        first_name: 'Applicant',
        last_name: 'Surname',
        form_number: '10-10D',
        file_name: 'a2345678-1234-5678-1234-567812345678_vha_10_10d2.pdf',
        s3_status: 'Submitted',
        pega_status: nil,
        case_id: nil,
        email_sent: false
      )

      ivc_forms = IvcChampvaForm.all

      batches = subject.batch_records(ivc_forms)

      # We should group by the two unique form_uuids that are present
      expect(batches.count).to eq(2)
      expect(batches.keys).to eq(
        %w[12345678-1234-5678-1234-567812345678
           a2345678-1234-5678-1234-567812345678]
      )
    end
  end
end
