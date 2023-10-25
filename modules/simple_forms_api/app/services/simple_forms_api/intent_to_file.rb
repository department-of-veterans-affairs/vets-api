# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module SimpleFormsApi
  class IntentToFile
    attr_reader :params, :icn

    def initialize(params, icn)
      @params = params
      @icn = icn
    end

    def submit
      benefit_selections = []
      params['benefit_selection'].each { |benefit_type, is_selected| benefit_selections << benefit_type if is_selected }
      ssn = params.dig('veteran_id', 'ssn')
      expiration_date = nil
      benefit_selections.each do |benefit_type|
        type = benefit_type.downcase
        next if existing_intents[type]

        response = benefits_claims_lighthouse_service.create_intent_to_file(type, ssn)
        expiration_date = response.dig('data', 'attributes', 'expirationDate')
      end

      expiration_date
    end

    def existing_intents
      @existing_intents ||= {
        'compensation' => existing_compensation_intent,
        'pension' => existing_pension_intent,
        'survivor' => existing_survivor_intent
      }
    end

    private

    def benefits_claims_lighthouse_service
      @benefits_claims_lighthouse_service ||= BenefitsClaims::Service.new(icn)
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
        "Simple forms api - #{type} intent to file not found. Form number: #{params[:form_number]},
          error: #{e}, ICN #{icn}"
      )
      nil
    end
  end
end
