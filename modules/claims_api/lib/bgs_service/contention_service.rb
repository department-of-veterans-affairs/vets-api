# frozen_string_literal: true

module ClaimsApi
  class ContentionService < ClaimsApi::LocalBGS
    def bean_name
      'ContentionService/ContentionService'
    end

    def find_contentions_by_ptcpnt_id(participant_id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId>#{participant_id}</ptcpntId>
      EOXML
      make_request(endpoint: bean_name, action: 'findContentionsByPtcpntId', body:)
    end

    def manage_contentions(options)
      validate_required_keys(required_manage_contentions_fields, options, __method__.to_s)

      contentions = options[:contentions].map do |contention|
        {
          clmId: contention[:clm_id],
          cntntnId: contention[:cntntn_id],
          specialIssues: contention[:special_issues].map do |special_issue|
            { spisTc: special_issue[:spis_tc] }
          end
        }
      end
      body = contentions_body(options)
      output = build_contentions_node(contentions, body)

      make_request(endpoint: bean_name, action: 'manageContentions', body: output)
    end

    private

    def validate_required_keys(required_keys, provided_hash, call)
      required_keys.each do |key|
        raise(ArgumentError, "#{key} is a required key in #{call}") unless provided_hash.key?(key)
        raise(ArgumentError, "#{key} cannot be empty or nil") if provided_hash[key].blank?
      end
    end

    def contentions_body(options)
      Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <BenefitClaim>
          <jrnDt>#{options[:jrn_dt]}</jrnDt>
          <bnftClmTc>#{options[:bnft_clm_tc]}</bnftClmTc>
          <bnftClmTn>#{options[:bnft_clm_tn]}</bnftClmTn>
          <claimRcvdDt>#{options[:claim_rcvd_dt]}</claimRcvdDt>
          <clmId>#{options[:clm_id]}</clmId>
          <lcSttRsnTc>#{options[:lc_stt_rsn_tc]}</lcSttRsnTc>
          <lcSttRsnTn>#{options[:lc_stt_rsn_tn]}</lcSttRsnTn>
          <lctnId>#{options[:lctn_id]}</lctnId>
          <nonMedClmDesc>#{options[:non_med_clm_desc]}</nonMedClmDesc>
          <prirty>#{options[:prirty]}</prirty>
          <ptcpntIdClmnt>#{options[:ptcpnt_id_clmnt]}</ptcpntIdClmnt>
          <ptcpntIdVet>#{options[:ptcpnt_id_vet]}</ptcpntIdVet>
          <ptcpntSuspnsId>#{options[:ptcpnt_suspns_id]}</ptcpntSuspnsId>
          <sojLctnId>#{options[:soj_lctn_id]}</sojLctnId>
        </BenefitClaim>
      EOXML
    end

    def build_contentions_node(contentions, body)
      doc = Nokogiri::XML(body.to_s)

      contentions.each do |contention|
        next unless contention[:specialIssues].any?

        contention_node = Nokogiri::XML::Node.new('contentions', doc)

        claim_id_node = Nokogiri::XML::Node.new('clmId', doc)
        contention_id_node = Nokogiri::XML::Node.new('cntntnId', doc)
        si_parent_node = Nokogiri::XML::Node.new('specialIssues', doc)

        claim_id_node.content = contention[:clmId]
        contention_id_node.content = contention[:cntntnId] if contention[:cntntnId]

        contention_node.add_child(claim_id_node)
        contention_node.add_child(contention_id_node)

        contention[:specialIssues].each do |si|
          si_node = Nokogiri::XML::Node.new('spisTc', doc)
          si_node.content = si.is_a?(Hash) ? si[:spisTc] : si
          si_parent_node.add_child(si_node)
        end

        contention_node.add_child(si_parent_node)
        doc.root.add_child(contention_node)
      end

      doc.root.to_xml(encoding: 'UTF-8', save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end

    def required_manage_contentions_fields
      %i[
        jrn_dt
        bnft_clm_tc
        bnft_clm_tn
        claim_rcvd_dt
        clm_id
        lc_stt_rsn_tc
        lc_stt_rsn_tn
        lctn_id
        non_med_clm_desc
        prirty
        ptcpnt_id_clmnt
        ptcpnt_id_vet
        ptcpnt_suspns_id
        soj_lctn_id
      ]
    end
  end
end
