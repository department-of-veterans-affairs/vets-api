# frozen_string_literal: true

require 'benchmark'
require 'hca/configuration'
require 'hca/overrides_parser'

module VA1010Forms
  module Utils
    include ActionView::Helpers::NumberHelper
    def es_submit(parsed_form, user_identifier, form_id)
      formatted = HCA::EnrollmentSystem.veteran_to_save_submit_form(parsed_form, user_identifier, form_id)
      submission_body = submission_body(formatted)
      response = perform(:post, '', submission_body)

      root = response.body.locate('S:Envelope/S:Body/submitFormResponse').first
      form_submission_id = root.locate('formSubmissionId').first.text.to_i

      {
        success: true,
        formSubmissionId: form_submission_id,
        timestamp: root.locate('timeStamp').first&.text || Time.now.getlocal.to_s
      }
    end

    def soap
      # Savon *seems* like it should be setting these things correctly
      # from what the docs say. Our WSDL file is weird, maybe?
      Savon.client(
        wsdl: HCA::Configuration::WSDL,
        env_namespace: :soap,
        element_form_default: :qualified,
        namespaces: {
          'xmlns:tns': 'http://va.gov/service/esr/voa/v1'
        },
        namespace: 'http://va.gov/schema/esr/voa/v1'
      )
    end

    private

    def submission_body(formatted_form)
      content =
        if Flipper.enabled?(:ezr_use_correct_format_for_file_uploads)
          Gyoku.xml(formatted_form, unwrap: [:'va:attachments'])
        else
          Gyoku.xml(formatted_form)
        end
      submission_body = soap.build_request(:save_submit_form, message: content).body
      log_payload_info(formatted_form, submission_body)

      submission_body
    end

    def log_payload_info(formatted_form, submission_body)
      form_name = formatted_form.dig('va:form', 'va:formIdentifier', 'va:value')
      attachments = formatted_form.dig('va:form', 'va:attachments')
      attachment_count = attachments&.length || 0
      # Log the attachment sizes in descending order
      if attachment_count.positive?
        # Convert the attachments into xml format so they resemble what will be sent to VES
        attachment_sizes =
          attachments.map { |a| a.to_xml.size }.sort.reverse!.map { |size| number_to_human_size(size) }.join(', ')

        Rails.logger.info("Attachment sizes in descending order: #{attachment_sizes}")
      end

      Rails.logger.info("Payload for submitted #{form_name}: " \
                        "Body size of #{number_to_human_size(submission_body.bytesize)} " \
                        "with #{attachment_count} attachment(s)")
    end
  end
end
