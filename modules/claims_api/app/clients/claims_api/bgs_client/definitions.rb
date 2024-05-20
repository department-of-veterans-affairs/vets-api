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
          :namespaces
        )

      # Auditing BGS for service actions that use more than one namespace, it
      # turns out that there is at most a second namespace used for data type
      # definitions. As such, we'll hardcode that notion and allow callers of
      # our BGS client to use an alias for it that we provide them.
      #   https://github.com/department-of-veterans-affairs/bgs-catalog/blob/main/namespaces.xml
      Namespaces =
        Data.define(
          :target,
          :data
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
          Bean.new(
            path: 'ClaimantServiceBean',
            namespaces: Namespaces.new(
              target: 'http://services.share.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      module ClaimantWebService
        DEFINITION =
          Service.new(
            bean: ClaimantServiceBean::DEFINITION,
            path: 'ClaimantWebService'
          )
      end

      ##
      # EBenefitsBnftClaimStatusWebServiceBean
      #
      module EBenefitsBenefitClaimStatusWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'EBenefitsBnftClaimStatusWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://services.share.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      module EBenefitsBenefitClaimStatusWebService
        DEFINITION =
          Service.new(
            bean: EBenefitsBenefitClaimStatusWebServiceBean::DEFINITION,
            path: 'EBenefitsBnftClaimStatusWebService'
          )
      end

      ##
      # VdcBean
      #
      module VdcBean
        DEFINITION =
          Bean.new(
            path: 'VDC',
            namespaces: Namespaces.new(
              target: 'http://gov.va.vba.benefits.vdc/services',
              data: 'http://gov.va.vba.benefits.vdc/data'
            )
          )
      end

      module ManageRepresentativeService
        DEFINITION =
          Service.new(
            bean: VdcBean::DEFINITION,
            path: 'ManageRepresentativeService'
          )

        module ReadPoaRequest
          DEFINITION =
            Action.new(
              service: ManageRepresentativeService::DEFINITION,
              name: 'readPOARequest'
            )
        end

        module ReadPoaRequestByParticipantId
          DEFINITION =
            Action.new(
              service: ManageRepresentativeService::DEFINITION,
              name: 'readPOARequestByPtcpntId'
            )
        end

        module UpdatePoaRequest
          DEFINITION =
            Action.new(
              service: ManageRepresentativeService::DEFINITION,
              name: 'updatePOARequest'
            )
        end
      end
    end
  end
end
