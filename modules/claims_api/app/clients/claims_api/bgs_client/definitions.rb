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

      ##
      # ContentionServiceBean
      #
      module ContentionService
        DEFINITION =
          Bean.new(
            path: 'ContentionService',
            namespaces: Namespaces.new(
              target: 'http://services.mapd.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      # CorporateUpdateServiceBean
      #
      module CorporateUpdateServiceBean
        DEFINITION =
          Bean.new(
            path: 'CorporateUpdateServiceBean',
            namespaces: Namespaces.new(
              target: 'http://services.share.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      module CorporateUpdateWebService
        DEFINITION =
          Service.new(
            bean: CorporateUpdateServiceBean::DEFINITION,
            path: 'CorporateUpdateWebService'
          )

        module UpdatePoaAccess
          DEFINITION =
            Action.new(
              service: CorporateUpdateWebService::DEFINITION,
              name: 'updatePoaAccess',
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
              target: 'http://claimstatus.services.ebenefits.vba.va.gov/',
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
      # IntentToFileWebServiceBean
      #
      module IntentToFileWebService
        DEFINITION =
          Bean.new(
            path: 'IntentToFileWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://intenttofile.services.vetsnet.vba.va.gov/',
              data: nil
            )
          )
      end

      ##
      # OrgWebServiceBean
      #
      module OrgWebService
        DEFINITION =
          Bean.new(
            path: 'OrgWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://org.services.vetsnet.vba.va.gov/',
              data: nil
            )
          )
      end

      ##
      # PersonWebServiceBean
      #
      module PersonWebService
        DEFINITION =
          Bean.new(
            path: 'PersonWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://person.services.vetsnet.vba.va.gov/',
              data: nil
            )
          )
      end

      ##
      # StandardDataService
      #
      module StandardDataService
        DEFINITION =
          Bean.new(
            path: 'StandardDataService',
            namespaces: Namespaces.new(
              target: 'http://services.mapd.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      ##
      # StandardDataWebServiceBean
      #
      module StandardDataWebService
        DEFINITION =
          Bean.new(
            path: 'StandardDataWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://standarddata.services.vetsnet.vba.va.gov/',
              data: nil
            )
          )
      end

      ##
      # TrackedItemService
      #
      # Adding 'Bean' to the end to differentiate from the service
      module TrackedItemServiceBean
        DEFINITION =
          Bean.new(
            path: 'TrackedItemService',
            namespaces: Namespaces.new(
              target: 'http://services.mapd.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      module TrackedItemService
        DEFINITION =
          Service.new(
            bean: TrackedItemServiceBean::DEFINITION,
            path: 'TrackedItemService'
          )

        module FindTrackedItems
          DEFINITION =
            Action.new(
              service: TrackedItemService::DEFINITION,
              name: 'findTrackedItems',
              key: 'BenefitClaim'
            )
        end
      end

      ##
      # Vdc
      #
      module Vdc
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
            bean: Vdc::DEFINITION,
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

        module UpdatePoaRelationship
          DEFINITION =
            Action.new(
              service: ManageRepresentativeService::DEFINITION,
              name: 'updatePOARelationship',
              key: 'POARelationshipReturnVO'
            )
        end
      end

      module VeteranRepresentativeService
        DEFINITION =
          Service.new(
            bean: Vdc::DEFINITION,
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

      ##
      # VetRecordService
      ##
      module VetRecordServiceBean
        DEFINITION =
          Bean.new(
            path: 'VetRecordServiceBean',
            namespaces: Namespaces.new(
              target: 'http://services.share.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      module VetRecordWebService
        DEFINITION =
          Service.new(
            bean: VetRecordServiceBean::DEFINITION,
            path: 'VetRecordWebService'
          )
      end

      # VnpAtchmsWebServiceBean
      #
      module VnpAtchmsWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'VnpAtchmsWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://atchmsService.services.vonapp.vba.va.gov/',
              data: nil
            )
          )
      end

      module VnpAtchmsService
        DEFINITION =
          Service.new(
            bean: VnpAtchmsWebServiceBean::DEFINITION,
            path: 'VnpAtchmsService'
          )

        module VnpAtchmsCreate
          DEFINITION =
            Action.new(
              service: VnpAtchmsService::DEFINITION,
              name: 'vnpAtchmsCreate',
              key: 'return'
            )
        end
      end

      ##
      # VnpPersonService
      #
      module VnpPersonWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'VnpPersonWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://personService.services.vonapp.vba.va.gov/',
              data: nil
            )
          )
      end

      module VnpPersonService
        DEFINITION =
          Service.new(
            bean: VnpPersonWebServiceBean::DEFINITION,
            path: 'VnpPersonService'
          )

        module FindPoaByParticipantId
          DEFINITION =
            Action.new(
              service: VnpPersonService::DEFINITION,
              name: 'vnpPersonCreate',
              key: 'return'
            )
        end
      end

      ##
      # VnpProcFormWebServiceBean
      #
      module VnpProcFormWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'VnpProcFormWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://procFormService.services.vonapp.vba.va.gov/',
              data: nil
            )
          )
      end

      module VnpProcFormService
        DEFINITION =
          Service.new(
            bean: VnpProcFormWebServiceBean::DEFINITION,
            path: 'VnpProcFormService'
          )

        module VnpProcFormCreate
          DEFINITION =
            Action.new(
              service: VnpProcFormService::DEFINITION,
              name: 'vnpProcFormCreate',
              key: 'return'
            )
        end
      end

      ##
      # VnpProcWebServiceBeanV2
      #
      module VnpProcWebServiceBeanV2
        DEFINITION =
          Bean.new(
            path: 'VnpProcWebServiceBeanV2',
            namespaces: Namespaces.new(
              target: 'http://procService.services.v2.vonapp.vba.va.gov/',
              data: nil
            )
          )
      end

      module VnpProcServiceV2
        DEFINITION =
          Service.new(
            bean: VnpProcWebServiceBeanV2::DEFINITION,
            path: 'VnpProcServiceV2'
          )

        module VnpProcCreate
          DEFINITION =
            Action.new(
              service: VnpProcServiceV2::DEFINITION,
              name: 'vnpProcCreate',
              key: 'return'
            )
        end
      end

      ##
      # VnpPtcpntAddrsWebServiceBean
      #
      module VnpPtcpntAddrsWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'VnpPtcpntAddrsWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://ptcpntAddrsService.services.vonapp.vba.va.gov/',
              data: nil
            )
          )
      end

      module VnpPtcpntAddrsService
        DEFINITION =
          Service.new(
            bean: VnpPtcpntAddrsWebServiceBean::DEFINITION,
            path: 'VnpPtcpntAddrsService'
          )

        module VnpPtcpntAddrsCreate
          DEFINITION =
            Action.new(
              service: VnpPtcpntAddrsService::DEFINITION,
              name: 'vnpPtcpntAddrsCreate',
              key: 'return'
            )
        end
      end

      ##
      # VnpPtcpntPhoneWebServiceBean
      #
      module VnpPtcpntPhoneWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'VnpPtcpntPhoneWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://ptcpntPhoneService.services.vonapp.vba.va.gov/',
              data: nil
            )
          )
      end

      module VnpPtcpntPhoneService
        DEFINITION =
          Service.new(
            bean: VnpPtcpntPhoneWebServiceBean::DEFINITION,
            path: 'VnpPtcpntPhoneService'
          )

        module FindPersonBySSN
          DEFINITION =
            Action.new(
              service: VnpPtcpntPhoneService::DEFINITION,
              name: 'vnpPtcpntPhoneCreate',
              key: 'return'
            )
        end
      end

      ##
      # VnpPtcpntWebServiceBean
      #
      module VnpPtcpntWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'VnpPtcpntWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://ptcpntService.services.vonapp.vba.va.gov/',
              data: nil
            )
          )
      end

      module VnpPtcpntService
        DEFINITION =
          Service.new(
            bean: VnpPtcpntWebServiceBean::DEFINITION,
            path: 'VnpPtcpntService'
          )

        module VnpPtcpntCreate
          DEFINITION =
            Action.new(
              service: VnpPtcpntService::DEFINITION,
              name: 'vnpPtcpntCreate',
              key: 'return'
            )
        end
      end
    end
  end
end
