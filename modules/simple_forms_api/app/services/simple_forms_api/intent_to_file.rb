# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module SimpleFormsApi
  class IntentToFile
    attr_reader :user, :icn, :params

    def initialize(user, params = {})
      @user = user
      @icn = user&.icn
      @params = params
    end

    def use_intent_api?
      params[:form_number] == '21-0966' && participant_id && icn && params[:preparer_identification] == 'VETERAN'
    end

    def submit
      benefit_selections = []
      params['benefit_selection'].each { |benefit_type, is_selected| benefit_selections << benefit_type if is_selected }
      ssn = params.dig('veteran_id', 'ssn')
      expiration_date = nil
      confirmation_number = nil
      benefit_selections.each do |benefit_type|
        type = benefit_type.downcase
        next if existing_intents[type]

        confirmation_number, expiration_date = create_intent_to_file(type, ssn)
      end

      user_account_uuid = user.user_account_uuid
      Rails.logger.info(
        'Simple forms api - sent to benefits claims api, intent to file create endpoint',
        { benefit_selections:, confirmation_number:, user_account_uuid: }
      )
      [confirmation_number, expiration_date]
    end

    def existing_intents
      @existing_intents ||= if icn && participant_id
                              {
                                'compensation' => existing_compensation_intent,
                                'pension' => existing_pension_intent,
                                'survivor' => existing_survivor_intent
                              }
                            else
                              {}
                            end
    end

    private

    def participant_id
      user&.participant_id
    end

    def benefits_claims_lighthouse_service
      @benefits_claims_lighthouse_service ||= BenefitsClaims::Service.new(icn)
    end

    def create_intent_to_file(type, ssn)
      response = benefits_claims_lighthouse_service.create_intent_to_file(type, ssn)
      [response.dig('data', 'id'), response.dig('data', 'attributes', 'expirationDate')]
    rescue Common::Exceptions::ResourceNotFound => e
      Rails.logger.error(
        'Simple forms api - Benefits Claims API, intent to file endpoint is down',
        {
          intent_type: type,
          form_number: params[:form_number],
          error: e
        }
      )
      raise Exceptions::BenefitsClaimsApiDownError
    end

    def existing_compensation_intent
      @existing_compensation_intent ||=
        benefits_claims_lighthouse_service.get_intent_to_file('compensation')&.dig('data', 'attributes')
    rescue Common::Exceptions::ResourceNotFound => e
      handle_missing_intent(e, 'compensation')
    end

    def existing_pension_intent
      @existing_pension_intent ||=
        benefits_claims_lighthouse_service.get_intent_to_file('pension')&.dig('data', 'attributes')
    rescue Common::Exceptions::ResourceNotFound => e
      handle_missing_intent(e, 'pension')
    end

    def existing_survivor_intent
      @existing_survivor_intent ||=
        benefits_claims_lighthouse_service.get_intent_to_file('survivor')&.dig('data', 'attributes')
    rescue Common::Exceptions::ResourceNotFound => e
      handle_missing_intent(e, 'survivor')
    end

    def handle_missing_intent(e, type)
      Rails.logger.info(
        'Simple forms api - intent to file not found',
        {
          intent_type: type,
          form_number: params[:form_number],
          error: e
        }
      )
      nil
    end
  end
end
