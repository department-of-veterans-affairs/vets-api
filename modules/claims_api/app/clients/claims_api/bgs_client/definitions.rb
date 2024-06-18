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
      # our BGS client to use an alias for it that we yield to them.
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
          :name,
          :key
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

        module FindPoaByParticipantId
          DEFINITION =
            Action.new(
              service: ClaimantWebService::DEFINITION,
              name: 'findPOAByPtcpntId',
              key: 'return'
            )
        end
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

        module FindBenefitClaimsStatusByParticipantId
          DEFINITION =
            Action.new(
              service: EBenefitsBenefitClaimStatusWebService::DEFINITION,
              name: 'findBenefitClaimsStatusByPtcpntId',
              key: 'BenefitClaimsDTO'
            )
        end
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
              name: 'readPOARequest',
              key: 'POARequestRespondReturnVO'
            )
        end

        module ReadPoaRequestByParticipantId
          DEFINITION =
            Action.new(
              service: ManageRepresentativeService::DEFINITION,
              name: 'readPOARequestByPtcpntId',
              key: 'POARequestRespondReturnVO'
            )
        end

        module UpdatePoaRequest
          DEFINITION =
            Action.new(
              service: ManageRepresentativeService::DEFINITION,
              name: 'updatePOARequest',
              key: 'POARequestUpdate'
            )
        end
      end

      ##
      # PersonWebServiceBean
      #
      module PersonWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'PersonWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://person.services.vetsnet.vba.va.gov/',
              data: 'http://person.services.vetsnet.vba.va.gov/'
            )
          )
      end

      module PersonWebService
        DEFINITION =
          Service.new(
            bean: PersonWebServiceBean::DEFINITION,
            path: 'PersonWebService'
          )
        module FindPersonBySSN
          DEFINITION =
            Action.new(
              service: PersonWebService::DEFINITION,
              name: 'findPersonBySSN',
              key: 'PersonDTO'
            )
        end
      end

      module VeteranRepresentativeService
        DEFINITION =
          Service.new(
            bean: VdcBean::DEFINITION,
            path: 'VeteranRepresentativeService'
          )

        module ReadAllVeteranRepresentatives
          DEFINITION =
            Action.new(
              service: VeteranRepresentativeService::DEFINITION,
              name: 'readAllVeteranRepresentatives',
              key: 'VeteranRepresentativeReturnList'
            )
        end

        module CreateVeteranRepresentative
          DEFINITION =
            Action.new(
              service: VeteranRepresentativeService::DEFINITION,
              name: 'createVeteranRepresentative',
              key: 'VeteranRepresentativeReturn'
            )
        end
      end
    end
  end
end
