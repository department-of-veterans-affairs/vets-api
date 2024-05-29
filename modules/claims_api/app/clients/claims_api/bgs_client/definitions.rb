# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    ##
    # Definitions of BGS services.
    #
    # If you need a particular definition, check for it or add it here.
    # A reference catalog is located at:
    #   https://github.com/department-of-veterans-affairs/bgs-catalog
    #
    # Request and response shapes are shown in files like these:
    #   `VDC/ManageRepresentativeService/ManageRepresentativePortBinding/readPOARequest/request.xml`
    #   `VDC/ManageRepresentativeService/ManageRepresentativePortBinding/readPOARequest/response.xml`
    #
    # ¡Keep these alphabetized by (bean, service, action)!
    #
    module Definitions
      Bean =
        Data.define(
          :path,
          :namespace,
          :data_namespace
        )

      Service =
        Data.define(:bean, :path) do
          def full_path
            [bean.path, path].join('/')
          end
        end

      Action =
        Data.define(
          :service,
          :name
        )

      ##
      # ClaimantServiceBean
      #
      module ClaimantServiceBean
        DEFINITION =
          Definitions::Bean.new(
            path: 'ClaimantServiceBean',
            namespace: 'http://services.share.benefits.vba.va.gov/',
            data_namespace: nil
          )
      end

      module ClaimantWebService
        DEFINITION =
          Definitions::Service.new(
            bean: ClaimantServiceBean::DEFINITION,
            path: 'ClaimantWebService'
          )
      end

      ##
      # EBenefitsBnftClaimStatusWebServiceBean
      #
      module EBenefitsBenefitClaimStatusWebServiceBean
        DEFINITION =
          Definitions::Bean.new(
            path: 'EBenefitsBnftClaimStatusWebServiceBean',
            namespace: 'http://services.share.benefits.vba.va.gov/',
            data_namespace: nil
          )
      end

      module EBenefitsBenefitClaimStatusWebService
        DEFINITION =
          Definitions::Service.new(
            bean: EBenefitsBenefitClaimStatusWebServiceBean::DEFINITION,
            path: 'EBenefitsBnftClaimStatusWebService'
          )
      end

      ##
      # VdcBean
      #
      module VdcBean
        DEFINITION =
          Definitions::Bean.new(
            path: 'VDC',
            namespace: 'http://gov.va.vba.benefits.vdc/services',
            data_namespace: 'http://gov.va.vba.benefits.vdc/data'
          )
      end

      module ManageRepresentativeService
        DEFINITION =
          Definitions::Service.new(
            bean: VdcBean::DEFINITION,
            path: 'ManageRepresentativeService'
          )

        module ReadPoaRequest
          DEFINITION =
            Definitions::Action.new(
              service: ManageRepresentativeService::DEFINITION,
              name: 'readPOARequest'
            )
        end

        module ReadPoaRequestByParticipantId
          DEFINITION =
            Definitions::Action.new(
              service: ManageRepresentativeService::DEFINITION,
              name: 'readPOARequestByPtcpntId'
            )
        end

        module UpdatePoaRequest
          DEFINITION =
            Definitions::Action.new(
              service: ManageRepresentativeService::DEFINITION,
              name: 'updatePOARequest'
            )
        end
      end
    end
  end
end
