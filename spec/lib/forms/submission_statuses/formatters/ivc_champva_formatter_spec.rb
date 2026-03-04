# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/formatters/ivc_champva_formatter'

describe Forms::SubmissionStatuses::Formatters::IvcChampvaFormatter,
         feature: :form_submission,
         team_owner: :health_apps_backend do
  subject(:formatter) { described_class.new }

  describe '#format_data' do
    it 'maps PEGA Processed status to vbms (received)' do
      submission = create(
        :ivc_champva_form,
        form_uuid: SecureRandom.uuid,
        form_number: '10-7959a',
        pega_status: 'Processed'
      )

      dataset = instance_double(
        Forms::SubmissionStatuses::Dataset,
        submissions?: true,
        submissions: [submission],
        intake_statuses?: false,
        intake_statuses: nil
      )

      result = formatter.format_data(dataset)

      expect(result.length).to eq(1)
      expect(result.first.form_type).to eq('10-7959A')
      expect(result.first.status).to eq('vbms')
      expect(result.first.pdf_support).to be(false)
    end

    it 'normalizes 10-10D-EXTENDED form type to 10-10D for card display' do
      submission = create(
        :ivc_champva_form,
        form_uuid: SecureRandom.uuid,
        form_number: '10-10D-EXTENDED',
        pega_status: 'Processed'
      )

      dataset = instance_double(
        Forms::SubmissionStatuses::Dataset,
        submissions?: true,
        submissions: [submission],
        intake_statuses?: false,
        intake_statuses: nil
      )

      result = formatter.format_data(dataset)

      expect(result.first.form_type).to eq('10-10D')
    end

    it 'maps PEGA Not Processed status to error (action needed)' do
      submission = create(
        :ivc_champva_form,
        form_uuid: SecureRandom.uuid,
        form_number: '10-10D',
        pega_status: 'Not Processed'
      )

      dataset = instance_double(
        Forms::SubmissionStatuses::Dataset,
        submissions?: true,
        submissions: [submission],
        intake_statuses?: false,
        intake_statuses: nil
      )

      result = formatter.format_data(dataset)

      expect(result.first.status).to eq('error')
    end

    it 'uses PEGA status precedence over VES and S3 statuses' do
      submission = create(
        :ivc_champva_form,
        form_uuid: SecureRandom.uuid,
        form_number: '10-10D',
        pega_status: 'Processed',
        ves_status: 'ok',
        s3_status: 'failed'
      )

      dataset = instance_double(
        Forms::SubmissionStatuses::Dataset,
        submissions?: true,
        submissions: [submission],
        intake_statuses?: false,
        intake_statuses: nil
      )

      result = formatter.format_data(dataset)

      expect(result.first.status).to eq('vbms')
    end

    it 'maps VES internal_server_error to error when PEGA status is missing' do
      submission = create(
        :ivc_champva_form,
        form_uuid: SecureRandom.uuid,
        form_number: '10-10D',
        pega_status: nil,
        ves_status: 'internal_server_error',
        s3_status: 'Submitted'
      )

      dataset = instance_double(
        Forms::SubmissionStatuses::Dataset,
        submissions?: true,
        submissions: [submission],
        intake_statuses?: false,
        intake_statuses: nil
      )

      result = formatter.format_data(dataset)

      expect(result.first.status).to eq('error')
    end

    it 'defaults unknown statuses to pending (in progress)' do
      submission = create(
        :ivc_champva_form,
        form_uuid: SecureRandom.uuid,
        form_number: '10-10D',
        ves_status: nil,
        pega_status: nil,
        s3_status: 'queued'
      )

      dataset = instance_double(
        Forms::SubmissionStatuses::Dataset,
        submissions?: true,
        submissions: [submission],
        intake_statuses?: false,
        intake_statuses: nil
      )

      result = formatter.format_data(dataset)

      expect(result.first.status).to eq('pending')
    end
  end
end
