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
      # BenefitClaimServiceBean
      #
      ##
      module BenefitClaimServiceBean
        DEFINITION =
          Bean.new(
            path: 'BenefitClaimServiceBean',
            namespaces: Namespaces.new(
              target: 'http://services.share.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      # BGS gave the same name to this service and the one below (BenefitClaimWebService), so
      # We changed the definition name to resemble the bean name.
      module BenefitClaimService
        DEFINITION =
          Service.new(
            bean: BenefitClaimServiceBean::DEFINITION,
            path: 'BenefitClaimWebService'
          )
      end

      ##
      # BenefitClaimWebServiceBean
      #
      ##
      module BenefitClaimWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'BenefitClaimWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://benefitclaim.services.vetsnet.vba.va.gov/',
              data: nil
            )
          )
      end

      module BenefitClaimWebService
        DEFINITION =
          Service.new(
            bean: BenefitClaimWebServiceBean::DEFINITION,
            path: 'BenefitClaimWebService'
          )
      end

      ##
      # ClaimantServiceBean
      # http://bepdev.vba.va.gov/ClaimantServiceBean/ClaimantWebService?WSDL
      ##
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
      # ClaimManagementService
      # http://bepdev.vba.va.gov/ClaimManagementService/ClaimManagementService?WSDL
      ##
      module ClaimManagementServiceBean
        DEFINITION =
          Bean.new(
            path: 'ClaimManagementService',
            namespaces: Namespaces.new(
              target: 'http://services.mapd.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      module ClaimManagementService
        DEFINITION =
          Service.new(
            bean: ClaimManagementServiceBean::DEFINITION,
            path: 'ClaimManagementService'
          )
      end

      ##
      # ContentionServiceBean
      # http://bepdev.vba.va.gov/ContentionService/ContentionService?WSDL
      ##
      module ContentionServiceBean
        DEFINITION =
          Bean.new(
            path: 'ContentionService',
            namespaces: Namespaces.new(
              target: 'http://services.mapd.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      module ContentionService
        DEFINITION =
          Service.new(
            bean: ContentionServiceBean::DEFINITION,
            path: 'ContentionService'
          )
      end

      # CorporateUpdateServiceBean
      # http://bepdev.vba.va.gov/CorporateUpdateServiceBean/CorporateUpdateWebService?WSDL
      ##
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
      end

      ##
      # EBenefitsBnftClaimStatusWebServiceBean
      #
      module EbenefitsBnftClaimStatusWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'EBenefitsBnftClaimStatusWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://claimstatus.services.ebenefits.vba.va.gov/',
              data: nil
            )
          )
      end

      module EbenefitsBnftClaimStatusWebService
        DEFINITION =
          Service.new(
            bean: EbenefitsBnftClaimStatusWebServiceBean::DEFINITION,
            path: 'EbenefitsBnftClaimStatusWebService'
          )
      end

      ##
      # IntentToFileWebServiceBean
      #
      module IntentToFileWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'IntentToFileWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://intenttofile.services.vetsnet.vba.va.gov/',
              data: nil
            )
          )
      end

      module IntentToFileWebService
        DEFINITION =
          Service.new(
            bean: IntentToFileWebServiceBean::DEFINITION,
            path: 'IntentToFileWebService'
          )
      end

      ##
      # OrgWebServiceBean
      #
      module OrgWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'OrgWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://org.services.vetsnet.vba.va.gov/',
              data: nil
            )
          )
      end

      module OrgWebService
        DEFINITION =
          Service.new(
            bean: OrgWebServiceBean::DEFINITION,
            path: 'OrgWebService'
          )
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
              data: nil
            )
          )
      end

      module PersonWebService
        DEFINITION =
          Service.new(
            bean: PersonWebServiceBean::DEFINITION,
            path: 'PersonWebService'
          )
      end

      ##
      # StandardDataService
      #
      module StandardDataServiceBean
        DEFINITION =
          Bean.new(
            path: 'StandardDataService',
            namespaces: Namespaces.new(
              target: 'http://services.mapd.benefits.vba.va.gov/',
              data: nil
            )
          )
      end

      module StandardDataService
        DEFINITION =
          Service.new(
            bean: StandardDataServiceBean::DEFINITION,
            path: 'StandardDataService'
          )
      end

      ##
      # StandardDataWebServiceBean
      # http://bepdev.vba.va.gov/StandardDataWebServiceBean/StandardDataWebService?WSDL
      ##
      module StandardDataWebServiceBean
        DEFINITION =
          Bean.new(
            path: 'StandardDataWebServiceBean',
            namespaces: Namespaces.new(
              target: 'http://standarddata.services.vetsnet.vba.va.gov/',
              data: nil
            )
          )
      end

      module StandardDataWebService
        DEFINITION =
          Service.new(
            bean: StandardDataWebServiceBean::DEFINITION,
            path: 'StandardDataWebService'
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
      end

      module VeteranRepresentativeService
        DEFINITION =
          Service.new(
            bean: Vdc::DEFINITION,
            path: 'VeteranRepresentativeService'
          )
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
      end
    end
  end
end
