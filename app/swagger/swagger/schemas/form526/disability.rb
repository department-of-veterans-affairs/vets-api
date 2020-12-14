# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class Disability
        include Swagger::Blocks

        swagger_schema :NewDisability do
          key :required, %i[condition cause]

          property :condition, type: :string
          property :cause, type: :string, enum:
            %w[
              NEW
              SECONDARY
              WORSENED
              VA
            ]
          property :classificationCode, type: :string
          property :primaryDescription, type: :string
          property :causedByDisability, type: :string
          property :causedByDisabilityDescription, type: :string
          property :specialIssues, type: :array do
            items do
              key :'$ref', :SpecialIssue
            end
          end
          property :worsenedDescription, type: :string
          property :worsenedEffects, type: :string
          property :vaMistreatmentDescription, type: :string
          property :vaMistreatmentLocation, type: :string
          property :vaMistreatmentDate, type: :string
        end

        swagger_schema :RatedDisability do
          key :required, %i[name disabilityActionType]

          property :name, type: :string
          property :disabilityActionType, type: :string, enum:
            %w[
              NONE
              NEW
              SECONDARY
              WORSENED
              VA
            ]
          property :specialIssues, type: :array do
            items do
              key :'$ref', :SpecialIssue
            end
          end
          property :ratedDisabilityId, type: :string
          property :ratingDecisionId, type: :string
          property :diagnosticCode, type: :number
          property :classificationCode, type: :string
          property :secondaryDisabilities, type: :array, maxItems: 100 do
            items type: :object do
              key :required, %i[name disabilityActionType]

              property :name, type: :string
              property :disabilityActionType, type: :string, enum:
                %w[
                  NONE
                  NEW
                  SECONDARY
                  WORSENED
                  VA
                ]
              property :specialIssues, type: :array do
                items do
                  key :'$ref', :SpecialIssue
                end
              end
              property :ratedDisabilityId, type: :string
              property :ratingDecisionId, type: :string
              property :diagnosticCode, type: :number
              property :classificationCode, type: :string
            end
          end
        end

        swagger_schema :SpecialIssue do
          property :items, type: :string, enum:
            %w[
              38USC1151
              AE
              AVC
              ANBP
              ADRL1
              ADRL2
              AOIV
              AOOV
              ASSOI
              ALS
              ELIGIBILITY
              ASB
              AE1
              ACTRES
              ARAD
              BE
              BRKD1BC
              BRKINT
              BPE
              C123
              COWC
              CD
              CHE
              CB
              CDOSV
              CRD
              CSRAQRS
              CSRER
              CSRE
              CSRMCS
              CSRO
              CSRO25
              CSRP
              CSRR
              DRCI
              DRCD
              DRCPD
              DBQP
              DBQV
              DRCEXRCA
              DRCEXRCD
              DPFS
              DRCVENEXRCMD
              DEEM
              DFR
              DOR
              DEP
              ECCD
              EDSP
              EHCL
              EHCLLOU
              GW
              ES3
              ESI4
              FEACS
              FEARINS
              FEAP
              FEAS
              FECP
              FDCCFP
              FDCEFC
              FEFCI
              FEFTE
              FENS
              FDCNED
              FERIVF
              FRDNFD
              FM
              FDC
              GWP
              HIV
              HEPC
              HA
              ID
              JSSRCRQST
              LH
              LMR
              LQR
              LQRIPR
              MFH
              MST
              MSSPA
              MG
              NATNLQUALREV
              NAPN
              NP
              NANL
              NNAPN
              PTSD/4
              PUO
              POW
              PTSD/1
              PTSD/2
              PTSD/3
              ROSI1
              ROSI2
              ROSPISTHR
              ROSPISFOR
              RSI5
              RSI6
              RSI7
              RSI8
              RSI9
              REN
              RDN
              RRDC
              RDR1
              RDR2
              RFE
              SSR
              SHAD
              SARCO
              SAANP
              SPECRECRQST
              S1D
              S2D
              S3D
              TER
              TMC
              T1H
              TOB
              TC
              TBI
              UV
              COSI1
              COSI2
              VACSPISTHR
              VACSPISFOR
              VACSPIS5
              VACSPIS6
              VACSPIS7
              VACSPIS8
              VACSPIS9
              VC
              VD
              VRD
              VEN
              VE
              VG
              VDG
              VH
              VI
              VML
              VM
              VN
              VRA
              VS
              VEXCLNODIAG
              VDC
              WARTAC
              WT
            ]
        end
      end
    end
  end
end
