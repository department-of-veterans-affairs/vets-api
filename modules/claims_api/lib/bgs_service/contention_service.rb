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

      response = make_request(endpoint: bean_name, action: 'findContentionsByPtcpntId', body:)
      byebug
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

      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <BenefitClaim>
          <jrnDt></jrnDt>
          <bnftClmTc></bnftClmTc>
          <bnftClmTn></bnftClmTn>
          <claimRcvdDt></claimRcvdDt>
          <clmId></clmId>
          <contentions>
            <clmId></clmId>
            <specialIssues>
              <spisTc></spisTc>
            </specialIssues>
          </contentions>
          <lcSttRsnTc></lcSttRsnTc>
          <lcSttRsnTn></lcSttRsnTn>
          <lctnId></lctnId>
          <nonMedClmDesc>e</nonMedClmDesc>
          <prirty></prirty>
          <ptcpntIdClmnt></ptcpntIdClmnt>
          <ptcpntIdVet></ptcpntIdVet>
          <ptcpntSuspnsId></ptcpntSuspnsId>
          <sojLctnId></sojLctnId>
        </BenefitClaim>
      EOXML

      response = request(
        :manage_contentions,
        {
          BenefitClaim: {
            jrnDt: options[:jrn_dt],
            bnftClmTc: options[:bnft_clm_tc],
            bnftClmTn: options[:bnft_clm_tn],
            claimRcvdDt: options[:claim_rcvd_dt],
            clmId: options[:clm_id],
            contentions: contentions,
            lcSttRsnTc: options[:lc_stt_rsn_tc],
            lcSttRsnTn: options[:lc_stt_rsn_tn],
            lctnId: options[:lctn_id],
            nonMedClmDesc: options[:non_med_clm_desc],
            prirty: options[:prirty],
            ptcpntIdClmnt: options[:ptcpnt_id_clmnt],
            ptcpntIdVet: options[:ptcpnt_id_vet],
            ptcpntSuspnsId: options[:ptcpnt_suspns_id],
            sojLctnId: options[:soj_lctn_id]
          }
        },
        options[:ptcpnt_id_clmnt]
      )
      response.body[:manage_contentions_response]
    end

    private

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