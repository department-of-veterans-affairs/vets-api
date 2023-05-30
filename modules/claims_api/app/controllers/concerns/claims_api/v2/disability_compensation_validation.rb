# frozen_string_literal: false

require 'brd/brd'

module ClaimsApi
  module V2
    module DisabilityCompensationValidation # rubocop:disable Metrics/ModuleLength
      def validate_form_526_submission_values!
        # ensure 'claimDate', if provided, is a valid date not in the future
        validate_form_526_submission_claim_date!
        # ensure 'claimantCertification' is true
        validate_form_526_claimant_certification!
        # ensure mailing address country is valid
        validate_form_526_current_mailing_address_country!
        # ensure homeless information is valid
        validate_form_526_veteran_homelessness!
        # ensure treament centers information is valid
        validate_form_526_treatments!
        # ensure service information is valid
        validate_form_526_service_information!
      end

      def validate_form_526_submission_claim_date!
        return if form_attributes['claimDate'].blank?
        # EVSS runs in the Central US Time Zone.
        # So 'claim_date' needs to be <= current day according to the Central US Time Zone.
        return if Date.parse(form_attributes['claimDate']) <= Time.find_zone!('Central Time (US & Canada)').today

        raise ::Common::Exceptions::InvalidFieldValue.new('claimDate', form_attributes['claimDate'])
      end

      def validate_form_526_claimant_certification!
        return unless form_attributes['claimantCertification'] == false

        raise ::Common::Exceptions::InvalidFieldValue.new('claimantCertification',
                                                          form_attributes['claimantCertification'])
      end

      def validate_form_526_current_mailing_address_country!
        mailing_address = form_attributes.dig('veteranIdentification', 'mailingAddress')
        return if valid_countries.include?(mailing_address['country'])

        raise ::Common::Exceptions::InvalidFieldValue.new('country', mailing_address['country'])
      end

      def valid_countries
        @valid_countries ||= ClaimsApi::BRD.new(request).countries
      end

      def validate_form_526_veteran_homelessness!
        handle_empty_other_description

        if too_many_homelessness_attributes_provided?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "Must define only one of 'homeless.currentlyHomeless' or " \
                    "'homeless.riskOfBecomingHomeless'"
          )
        end

        if unnecessary_homelessness_point_of_contact_provided?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "If 'homeless.pointOfContact' is defined, then one of " \
                    "'homeless.currentlyHomeless' or 'homeless.riskOfBecomingHomeless' is required"
          )
        end

        if missing_point_of_contact?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: "If one of 'homeless.currentlyHomeless' or 'homeless.riskOfBecomingHomeless' is " \
                    "defined, then 'homeless.pointOfContact' is required"
          )
        end
      end

      def get_homelessness_attributes
        currently_homeless_attr = form_attributes.dig('homeless', 'currentlyHomeless')
        homelessness_risk_attr = form_attributes.dig('homeless', 'riskOfBecomingHomeless')
        [currently_homeless_attr, homelessness_risk_attr]
      end

      def handle_empty_other_description
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes

        # Set otherDescription to ' ' to bypass docker container validation
        if currently_homeless_attr.present?
          homeless_situation_options = currently_homeless_attr['homelessSituationOptions']
          other_description = currently_homeless_attr['otherDescription']
          if homeless_situation_options == 'OTHER' && other_description.blank?
            form_attributes['homeless']['currentlyHomeless']['otherDescription'] = ' '
          end
        elsif homelessness_risk_attr.present?
          living_situation_options = homelessness_risk_attr['livingSituationOptions']
          other_description = homelessness_risk_attr['otherDescription']
          if living_situation_options == 'other' && other_description.blank?
            form_attributes['homeless']['riskOfBecomingHomeless']['otherDescription'] = ' '
          end
        end
      end

      def too_many_homelessness_attributes_provided?
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes
        # EVSS does not allow both attributes to be provided at the same time
        currently_homeless_attr.present? && homelessness_risk_attr.present?
      end

      def unnecessary_homelessness_point_of_contact_provided?
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes
        homelessness_poc_attr = form_attributes.dig('homeless', 'pointOfContact')

        # EVSS does not allow passing a 'pointOfContact' if neither homelessness attribute is provided
        currently_homeless_attr.blank? && homelessness_risk_attr.blank? && homelessness_poc_attr.present?
      end

      def missing_point_of_contact?
        homelessness_poc_attr = form_attributes.dig('homeless', 'pointOfContact')
        currently_homeless_attr, homelessness_risk_attr = get_homelessness_attributes

        # 'pointOfContact' is required when either currentlyHomeless or homelessnessRisk is provided
        homelessness_poc_attr.blank? && (currently_homeless_attr.present? || homelessness_risk_attr.present?)
      end

      def validate_form_526_treatments!
        treatments = form_attributes['treatments']
        return if treatments.blank?

        validate_treated_disability_names!
      end

      def validate_treated_disability_names!
        treatments = form_attributes['treatments']

        treated_disability_names = collect_treated_disability_names(treatments)
        declared_disability_names = collect_primary_secondary_disability_names(form_attributes['disabilities'])

        treated_disability_names.each do |treatment|
          next if declared_disability_names.include?(treatment)

          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: 'The treated disability must match a disability listed above'
          )
        end
      end

      def collect_treated_disability_names(treatments)
        names = []
        treatments.each do |treatment|
          if treatment['treatedDisabilityNames'].blank?
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'Treated disability names are required.'
            )
          end

          treatment['treatedDisabilityNames'].each do |disability_name|
            names << disability_name.strip.downcase
          end
        end
        names
      end

      def collect_primary_secondary_disability_names(disabilities)
        names = []
        disabilities.each do |disability|
          names << disability['name'].strip.downcase
          disability['secondaryDisabilities'].each do |secondary|
            names << secondary['name'].strip.downcase
          end
        end
        names
      end

      def validate_form_526_service_information!
        service_information = form_attributes['serviceInformation']

        if service_information.blank?
          raise ::Common::Exceptions::UnprocessableEntity.new(
            detail: 'Service information is required'
          )
        end

        validate_service_periods!
        validate_confinements!
      end

      def validate_service_periods!
        service_information = form_attributes['serviceInformation']

        service_information['servicePeriods'].each do |sp|
          if Date.parse(sp['activeDutyBeginDate']) > Date.parse(sp['activeDutyEndDate'])
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'Active Duty End Date needs to be after Active Duty Start Date'
            )
          end

          if Date.parse(sp['activeDutyEndDate']) > Time.zone.now && sp['separationLocationCode'].empty?
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'If Active Duty End Date is in the future a Separation Location Code is required.'
            )
          end
        end
      end

      def validate_confinements!
        service_information = form_attributes['serviceInformation']

        service_information['confinements'].each do |confinement|
          approximate_begin_date = confinement['approximateBeginDate']
          approximate_end_date = confinement['approximateEndDate']
          if Date.parse(approximate_begin_date) > Date.parse(approximate_end_date)
            raise ::Common::Exceptions::UnprocessableEntity.new(
              detail: 'Approximate end date must be after approximate begin date.'
            )
          end
        end
      end
    end
  end
end
