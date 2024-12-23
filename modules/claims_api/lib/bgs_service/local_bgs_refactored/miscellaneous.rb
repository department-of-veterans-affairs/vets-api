# frozen_string_literal: true

require 'claims_api/evss_bgs_mapper'

module ClaimsApi
  class LocalBGSRefactored
    module Miscellaneous # rubocop:disable Metrics/ModuleLength
      def find_poa_by_participant_id(id)
        body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <ptcpntId />
        EOXML

        { ptcpntId: id }.each do |k, v|
          body.xpath("./*[local-name()='#{k}']")[0].content = v
        end

        make_request(endpoint: 'ClaimantServiceBean/ClaimantWebService', action: 'findPOAByPtcpntId', body:,
                     key: 'return')
      end

      def find_by_ssn(ssn)
        body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <ssn />
        EOXML

        { ssn: }.each do |k, v|
          body.xpath("./*[local-name()='#{k}']")[0].content = v
        end

        make_request(endpoint: 'PersonWebServiceBean/PersonWebService', action: 'findPersonBySSN', body:,
                     key: 'PersonDTO')
      end

      def find_benefit_claims_status_by_ptcpnt_id(id)
        body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <ptcpntId />
        EOXML

        { ptcpntId: id }.each do |k, v|
          body.xpath("./*[local-name()='#{k}']")[0].content = v
        end

        make_request(endpoint: 'EBenefitsBnftClaimStatusWebServiceBean/EBenefitsBnftClaimStatusWebService',
                     action: 'findBenefitClaimsStatusByPtcpntId', body:)
      end

      def claims_count(id)
        find_benefit_claims_status_by_ptcpnt_id(id).count
      rescue ::Common::Exceptions::ResourceNotFound
        0
      end

      def find_benefit_claim_details_by_benefit_claim_id(id)
        body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <bnftClaimId />
        EOXML

        { bnftClaimId: id }.each do |k, v|
          body.xpath("./*[local-name()='#{k}']")[0].content = v
        end

        make_request(endpoint: 'EBenefitsBnftClaimStatusWebServiceBean/EBenefitsBnftClaimStatusWebService',
                     action: 'findBenefitClaimDetailsByBnftClaimId', body:)
      end

      def insert_intent_to_file(options)
        request_body = construct_itf_body(options)
        body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <intentToFileDTO>
          </intentToFileDTO>
        EOXML

        request_body.each do |k, z|
          node = Nokogiri::XML::Node.new k.to_s, body
          node.content = z.to_s
          opt = body.at('intentToFileDTO')
          node.parent = opt
        end
        make_request(endpoint: 'IntentToFileWebServiceBean/IntentToFileWebService', action: 'insertIntentToFile',
                     body:, key: 'IntentToFileDTO')
      end

      def find_tracked_items(id)
        body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <claimId />
        EOXML

        { claimId: id }.each do |k, v|
          body.xpath("./*[local-name()='#{k}']")[0].content = v
        end

        make_request(endpoint: 'TrackedItemService/TrackedItemService', action: 'findTrackedItems', body:,
                     key: 'BenefitClaim')
      end

      def find_intent_to_file_by_ptcpnt_id_itf_type_cd(id, type)
        body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <ptcpntId></ptcpntId><itfTypeCd></itfTypeCd>
        EOXML

        ptcpnt_id = body.at 'ptcpntId'
        ptcpnt_id.content = id.to_s
        itf_type_cd = body.at 'itfTypeCd'
        itf_type_cd.content = type.to_s

        response =
          make_request(
            endpoint: 'IntentToFileWebServiceBean/IntentToFileWebService',
            action: 'findIntentToFileByPtcpntIdItfTypeCd',
            body:
          )

        Array.wrap(response[:intent_to_file_dto])
      end

      # BEGIN: switching v1 from evss to bgs. Delete after EVSS is no longer available. Fix controller first.
      def update_from_remote(id)
        bgs_claim = find_benefit_claim_details_by_benefit_claim_id(id)
        transform_bgs_claim_to_evss(bgs_claim)
      end

      def all(id)
        claims = find_benefit_claims_status_by_ptcpnt_id(id)
        return [] if claims.count < 1 || claims[:benefit_claims_dto].blank?

        transform_bgs_claims_to_evss(claims)
      end
      # END: switching v1 from evss to bgs. Delete after EVSS is no longer available. Fix controller first.

      def construct_itf_body(options)
        request_body = {
          itfTypeCd: options[:intent_to_file_type_code],
          ptcpntVetId: options[:participant_vet_id],
          rcvdDt: options[:received_date],
          signtrInd: options[:signature_indicated],
          submtrApplcnTypeCd: options[:submitter_application_icn_type_code]
        }
        request_body[:ptcpntClmantId] = options[:participant_claimant_id] if options.key?(:participant_claimant_id)
        request_body[:clmantSsn] = options[:claimant_ssn] if options.key?(:claimant_ssn)
        request_body
      end

      def transform_bgs_claim_to_evss(claim)
        bgs_claim = ClaimsApi::EvssBgsMapper.new(claim[:benefit_claim_details_dto])
        return if bgs_claim.nil?

        bgs_claim.map_and_build_object
      end

      def transform_bgs_claims_to_evss(claims)
        claims_array = [claims[:benefit_claims_dto][:benefit_claim]].flatten
        claims_array&.map do |claim|
          bgs_claim = ClaimsApi::EvssBgsMapper.new(claim)
          bgs_claim.map_and_build_object
        end
      end

      def convert_nil_values(options)
        arg_strg = ''
        options.each do |option|
          arg = option[0].to_s.camelize(:lower)
          arg_strg += (option[1].nil? ? "<#{arg} xsi:nil='true'/>" : "<#{arg}>#{option[1]}</#{arg}>")
        end
        arg_strg
      end

      def validate_opts!(opts, required_keys)
        keys = opts.keys.map(&:to_s)
        required_keys = required_keys.map(&:to_s)
        missing_keys = required_keys - keys
        raise ArgumentError, "Missing required keys: #{missing_keys.join(', ')}" if missing_keys.present?
      end

      def jrn
        {
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_status_type_cd: 'U',
          jrn_user_id: Settings.bgs.client_username,
          jrn_obj_id: Settings.bgs.application
        }
      end

      def to_camelcase(claim:)
        claim.deep_transform_keys { |k| k.to_s.camelize(:lower) }
      end
    end
  end
end
