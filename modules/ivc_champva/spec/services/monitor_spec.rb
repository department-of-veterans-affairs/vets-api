# frozen_string_literal: true

require 'rails_helper'
require_relative '../../lib/ivc_champva/monitor'

RSpec.describe IvcChampva::Monitor do
  let(:monitor) { described_class.new }

  describe '#track_request' do
    it 'delegates to the parent class track_request method' do
      expect(monitor).to receive(:track_request).with(
        'info', 'Test message', 'test.key', foo: 'bar'
      )

      monitor.send(:track_request, 'info', 'Test message', 'test.key', foo: 'bar')
    end
  end

  context 'with params supplied' do
    describe '#track_update_status' do
      it 'logs sidekiq success' do
        payload = {
          form_uuid: '12345678-1234-5678-1234-567812345678',
          status: 'Processed'
        }

        expect(monitor).to receive(:track_update_status).with(
          payload[:form_uuid], payload[:status]
        )
        monitor.track_update_status(payload[:form_uuid], payload[:status])
      end

      it 'handles nil status gracefully' do
        form_uuid = '12345678-1234-5678-1234-567812345678'
        allow(monitor).to receive(:track_request)

        expect { monitor.track_update_status(form_uuid, nil) }.not_to raise_error
      end
    end

    describe '#track_insert_form' do
      it 'logs sidekiq success' do
        payload = {
          form_uuid: '12345678-1234-5678-1234-567812345678',
          form_id: 'vha_10_10d'
        }

        expect(monitor).to receive(:track_insert_form).with(
          payload[:form_uuid], payload[:form_id]
        )
        monitor.track_insert_form(payload[:form_uuid], payload[:form_id])
      end
    end

    describe '#track_missing_status_email_sent' do
      it 'logs sidekiq success' do
        payload = {
          form_id: 'vha_10_10d'
        }

        expect(monitor).to receive(:track_missing_status_email_sent).with(
          payload[:form_id]
        )
        monitor.track_missing_status_email_sent(payload[:form_id])
      end
    end

    describe '#track_send_zsf_notification_to_pega' do
      it 'logs sidekiq success' do
        payload = {
          form_uuid: '12345678-1234-5678-1234-567812345678'
        }

        expect(monitor).to receive(:track_send_zsf_notification_to_pega).with(
          payload[:form_uuid],
          'fake-template'
        )
        monitor.track_send_zsf_notification_to_pega(payload[:form_uuid], 'fake-template')
      end
    end

    describe '#track_failed_send_zsf_notification_to_pega' do
      it 'logs sidekiq success' do
        payload = {
          form_uuid: '12345678-1234-5678-1234-567812345678'
        }

        expect(monitor).to receive(:track_failed_send_zsf_notification_to_pega).with(
          payload[:form_uuid],
          'fake-template'
        )
        monitor.track_failed_send_zsf_notification_to_pega(payload[:form_uuid], 'fake-template')
      end
    end

    describe '#track_s3_upload_file_error' do
      it 'logs sidekiq success' do
        payload = {
          key: 'test_form.pdf',
          file_path: 'test_form.pdf'
        }

        expect(monitor).to receive(:track_s3_upload_file_error).with(
          payload[:key],
          payload[:file_path]
        )
        monitor.track_s3_upload_file_error(payload[:key], payload[:file_path])
      end

      it 'properly handles error with nil backtrace' do
        key = 'test_key.pdf'
        error = StandardError.new('Test error')
        allow(error).to receive(:backtrace).and_return(nil)

        expect(monitor).to receive(:track_request)

        monitor.track_s3_upload_file_error(key, error)
      end
    end

    describe '#track_all_successful_s3_uploads' do
      it 'logs sidekiq success' do
        payload = {
          key: 'test_form.pdf'
        }

        expect(monitor).to receive(:track_all_successful_s3_uploads).with(
          payload[:key]
        )
        monitor.track_all_successful_s3_uploads(payload[:key])
      end
    end

    describe '#track_s3_put_object_error' do
      let(:error) { StandardError.new('Test Error Message') }
      let(:key) { 'test_file.pdf' }

      it 'tracks S3 PutObject error without response' do
        expect(monitor).to receive(:track_s3_put_object_error).with(
          key, error, nil # Expectation is correct with nil
        )

        monitor.track_s3_put_object_error(key, error, nil) # Call with nil
      end

      it 'handles various response scenarios' do
        # Test case configurations
        test_cases = [
          # [description, response_setup]
          ['complete response', double('response', status: 500, body: double('body', read: 'Error body'))],
          ['response without body', lambda { |resp|
            allow(resp).to receive(:respond_to?).with(:body).and_return(false)
          }],
          ['response with non-readable body', lambda { |resp|
            allow(resp).to receive(:body).and_return(double('body'))
            allow(resp.body).to receive(:respond_to?).with(:read).and_return(false)
          }]
        ]

        test_cases.each do |description, response_setup|
          response = double('response', status: 500)

          # Configure the response based on the test case
          response_setup.is_a?(Proc) ? response_setup.call(response) : response = response_setup

          # Set up default behaviors for respond_to? calls if not a complete double
          if response_setup.is_a?(Proc)
            allow(response).to receive(:respond_to?).with(:status).and_return(true)
            allow(response).to receive(:respond_to?).with(:body).and_return(true) unless
              description == 'response without body'
          end

          # Verify the behavior
          expect(monitor).to receive(:track_request)
          monitor.track_s3_put_object_error(key, error, response)
        end
      end
    end

    describe '#track_email_sent' do
      it 'logs sidekiq success' do
        payload = {
          form_id: '10-10d',
          form_uuid: '12345678-1234-5678-1234-567812345678',
          delivery_status: 'delivered',
          notification_type: 'confirmation'
        }

        expect(monitor).to receive(:track_email_sent).with(
          payload[:form_id],
          payload[:form_uuid],
          payload[:delivery_status],
          payload[:notification_type]
        )
        monitor.track_email_sent(
          payload[:form_id],
          payload[:form_uuid],
          payload[:delivery_status],
          payload[:notification_type]
        )
      end

      it 'handles edge cases with nil values' do
        allow(monitor).to receive(:track_request)

        expect do
          monitor.track_email_sent(nil, nil, nil, nil)
        end.not_to raise_error
      end
    end

    describe '#track_s3_upload_error' do
      it 'calls track_request with the correct parameters' do
        form_uuid = '12345678-1234-5678-1234-567812345678'
        s3_err = 'Failed to upload file to S3'

        additional_context = {
          form_uuid:,
          s3_err:
        }

        expect(monitor).to receive(:track_request).with(
          'warn',
          "IVC ChampVa Forms - failed to upload all documents for submission: #{form_uuid}",
          "#{IvcChampva::Monitor::STATS_KEY}.s3_upload_error",
          call_location: anything,
          **additional_context
        )

        monitor.track_s3_upload_error(form_uuid, s3_err)
      end

      it 'handles edge cases with empty or nil values' do
        [
          ['', ''],
          [nil, nil],
          ['12345678-1234-5678-1234-567812345678', nil],
          [nil, 'Some error message']
        ].each do |form_uuid, s3_err|
          expect(monitor).to receive(:track_request)
          monitor.track_s3_upload_error(form_uuid, s3_err)
        end
      end
    end

    describe '#track_pdf_stamper_error' do
      it 'calls track_request with the correct parameters' do
        form_uuid = '12345678-1234-5678-1234-567812345678',
                    err_message = 'oh no'

        additional_context = {
          form_uuid:,
          err_message:
        }

        expect(monitor).to receive(:track_request).with(
          'warn',
          "IVC ChampVa Forms - an error occurred during pdf stamping: #{form_uuid}",
          "#{IvcChampva::Monitor::STATS_KEY}.pdf_stamper_error",
          call_location: anything,
          **additional_context
        )

        monitor.track_pdf_stamper_error(form_uuid, err_message)
      end

      it 'handles edge cases with empty or nil values' do
        [
          ['', ''],
          [nil, nil],
          ['12345678-1234-5678-1234-567812345678', nil],
          [nil, 'Some error message']
        ].each do |form_uuid, err_message|
          expect(monitor).to receive(:track_request)
          monitor.track_pdf_stamper_error(form_uuid, err_message)
        end
      end
    end

    describe '#track_ves_response' do
      # rubocop:disable Layout/LineLength
      it 'on success, calls track_request with the correct parameters' do
        form_uuid = '12345678-1234-5678-1234-567812345678',
                    status = 200,
                    messages = '{"messages": [{"code": "abc123", "key": "someKey", "text": "someText", "severity": "INFO", "potentiallySelfCorrectingOnRetry": true}]}'

        additional_context = {
          form_uuid:,
          status:,
          messages:
        }

        expect(monitor).to receive(:track_request).with(
          'info',
          "IVC ChampVa Forms - Successful submission to VES for form #{form_uuid}",
          "#{IvcChampva::Monitor::STATS_KEY}.ves_response.success",
          call_location: anything,
          **additional_context
        )

        monitor.track_ves_response(form_uuid, status, messages)
      end

      it 'on failure, calls track_request with the correct parameters' do
        form_uuid = '12345678-1234-5678-1234-567812345678',
                    status = 500,
                    messages = '{"messages": [{"code": "abc123", "key": "someKey", "text": "someText", "severity": "INFO", "potentiallySelfCorrectingOnRetry": true}]}'

        additional_context = {
          form_uuid:,
          status:,
          messages:
        }

        expect(monitor).to receive(:track_request).with(
          'error',
          "IVC ChampVa Forms - Error on submission to VES for form #{form_uuid}",
          "#{IvcChampva::Monitor::STATS_KEY}.ves_response.failure",
          call_location: anything,
          **additional_context
        )

        monitor.track_ves_response(form_uuid, status, messages)
      end

      it 'handles nil response' do
        form_uuid = '12345678-1234-5678-1234-567812345678'
        status = nil
        messages = nil

        additional_context = {
          form_uuid:,
          status:,
          messages:
        }

        expect(monitor).to receive(:track_request).with(
          'error',
          "IVC ChampVa Forms - Error on submission to VES for form #{form_uuid}",
          "#{IvcChampva::Monitor::STATS_KEY}.ves_response.failure",
          call_location: anything,
          **additional_context
        )

        monitor.track_ves_response(form_uuid, status, messages)
      end
      # rubocop:enable Layout/LineLength
    end
  end
end
