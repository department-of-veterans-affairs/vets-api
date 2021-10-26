# frozen_string_literal: true

require 'evss/service'
require_relative 'configuration'

module EVSS
  module Dependents
    ##
    # Proxy Service for Dependents Caseflow.
    #
    # @example Create a service and submitting a 686 form
    #   dependents_response = Dependents::Service.new.submit(form, form_id)
    #
    class Service < EVSS::Service
      configuration EVSS::Dependents::Configuration

      STATSD_KEY_PREFIX = 'api.evss.dependents'

      ##
      # Fetches user info from the retrieve endpoint.
      #
      # @return [Faraday::Response] Faraday response instance.
      #
      def retrieve
        with_monitoring_and_error_handling do
          perform(:get, 'load/retrieve')
        end
      end

      ##
      # Cleans in-flight form using form hash.
      #
      # @param form [Hash] The form data.
      # @return [Object] Faraday response body.
      #
      def clean_form(form)
        with_monitoring_and_error_handling do
          perform(:post, 'inflightform/cleanForm', form.to_json, headers).body
        end
      end

      ##
      # Validates in-flight form using form hash.
      #
      # @param form [Hash] The form data.
      # @return [Object] Faraday response body.
      #
      def validate(form)
        with_monitoring_and_error_handling do
          perform(:post, 'inflightform/validateForm', form.to_json, headers).body
        end
      end

      ##
      # Saves in-flight form using form hash.
      #
      # @param form [Hash] The form data.
      # @return [Object] Faraday response body.
      #
      def save(form)
        with_monitoring_and_error_handling do
          perform(:post, 'inflightform/saveForm', form.to_json, headers).body
        end
      end

      ##
      # Submits 686 form with form ID
      #
      # @param form [Hash] The form data.
      # @param form_id [String] The form ID to be added to the form hash.
      # @return [Hash] The response body in hash form.
      #
      def submit(form, form_id)
        form['submitProcess']['application']['draftFormId'] = form_id
        change_evss_times!(form)
        with_monitoring_and_error_handling do
          res = perform(
            :post,
            'form686submission/submit',
            form.to_xml(root: 'submit686Request'),
            'Content-Type' => 'application/xml'
          )
          Hash.from_xml(res.body)
        end
      end

      private

      def change_evss_times!(object)
        case object
        when Hash
          object.each do |k, v|
            if k.downcase.include?('date') && v.is_a?(Numeric)
              object[k] = convert_evss_time(v)
            else
              change_evss_times!(v)
            end
          end
        when Array
          object.each do |item|
            change_evss_times!(item)
          end
        end
      end

      def convert_evss_time(time)
        Time.strptime(time.to_s, '%Q').utc.iso8601
      end
    end
  end
end
