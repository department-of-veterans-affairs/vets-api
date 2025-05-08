# frozen_string_literal: true

require 'mail_automation/configuration'

# This client is written for the specific purpose of handing off certain benefit claims
# to the MAS portion of the current system
module MailAutomation
  class Client < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    configuration MailAutomation::Configuration

    # Initializes the MAS client.
    #
    # @example
    #
    # MailAutomation::Client.new({
    #   claim_id: 1234
    #   file_number: 1234
    #   form526: {}
    # })
    def initialize(params)
      @claim_id = params[:claim_id]
      @file_number = params[:file_number]
      @form526 = params[:form526]

      raise ArgumentError, 'no file_number passed in for API request.' if @file_number.blank?
      raise ArgumentError, 'no claim_id passed in for API request.' if @claim_id.blank?
      raise ArgumentError, 'no form526 passed in for API request.' if @form526.blank?
      raise ArgumentError, 'no disabilities passed in for API request.' if @form526.dig('form526', 'form526',
                                                                                        'disabilities').blank?
    end

    def initiate_apcas_processing
      params = {
        file_number: @file_number,
        claim_id: @claim_id,
        form526: @form526['form526']
      }
      if Flipper.enabled?(:disability_526_send_mas_all_ancillaries)
        params.merge!(@form526.slice(*%w[form526_uploads form4142 form0781]).symbolize_keys)
      end

      perform(:post, Settings.mail_automation.endpoint, params.to_json.to_s, headers_hash)
    end

    private

    def authenticate(params)
      perform(
        :post,
        Settings.mail_automation.token_endpoint,
        URI.encode_www_form(params),
        { 'Content-Type': 'application/x-www-form-urlencoded' }
      )
    end

    def headers_hash
      Configuration.base_request_headers.merge({ Authorization: "Bearer #{retrieve_bearer_token}" })
    end

    # NOTE: This is intentionally not memoized because each request needs to re-authorize
    def retrieve_bearer_token
      authenticate(authentication_body).body['access_token']
    end

    def authentication_body
      {
        grant_type: 'client_credentials',
        scope: 'openid',
        client_id: Settings.mail_automation.client_id,
        client_secret: Settings.mail_automation.client_secret
      }.as_json
    end
  end
end
