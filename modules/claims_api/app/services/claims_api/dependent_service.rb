# frozen_string_literal: true

module ClaimsApi
  class DependentService
    SPONSOR_BGS_CLAIM_TYPES = %w[020RSCDTH 020RSCDTHPMC 130ISDDI 130ISDDIPMC 130RDBPMC 140ISCD 140ISCDP 140ISCDPMC
                                 140ISCDPPIMC 140ISD 144REPSIPMC 144REPSISCD 145REPSIPMC 145REPSISCD 146REPSIPMC
                                 146REPSISCD 190AIDP 190ORGDPN 190ORGOPNPMC 290DG 290DGPMC 299AMDP 600DDM 600PDDM
                                 810FTD 810PRDPE 820SSADCPM 820SSADDCPM 820SSADDDM 820SSADDM 820SSADSNM 820SSASNM
                                 830DCOF 830DMMF 830DNFBST].freeze

    def initialize(**args)
      @bgs_claim = args&.dig(:bgs_claim)
    end

    def dependent_type_claim?(bgs_claim = @bgs_claim)
      SPONSOR_BGS_CLAIM_TYPES.include? bgs_claim&.dig(:benefit_claim_details_dto, :bnft_claim_type_cd)
    end
  end
end
