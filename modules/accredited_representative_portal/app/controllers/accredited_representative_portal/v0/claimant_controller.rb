# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class ClaimantController < ApplicationController
      before_action :check_feature_toggle
      skip_after_action :verify_pundit_authorization

      def show
        # Rendering mock data until controller action is built to fetch MPI data, and subsequent
        # LH call to retrieve active PoA.
        render json: {
          claimant: {
            firstName: 'Jon',
            lastName: 'Snow',
            city: 'Eau Claire',
            state: 'WI',
            postalCode: '54701',
            # will show false if poa is pending
            poaStatus: 'declined',
            # will only show if poa_status is true
            representative: 'Wounded Warriors',
            # for accessing claimant page
            icnTemporaryIdentifier: '7e7fbda9-49db-4206-aedb-5e9783556d79', 
            poaRequests: [{
               "claimantId"=>"8bea4d28-da9f-43eb-836f-6d24b4bb5061",
               "createdAt"=>"2025-03-26T12:53:17.249Z",
               "expiresAt"=>nil,
               "powerOfAttorneyForm"=>
                {"authorizations"=>{"recordDisclosure"=>true, "recordDisclosureLimitations"=>["ALCOHOLISM", "DRUG_ABUSE"], "addressChange"=>false},
                 "claimant"=>
                  {"name"=>{"first"=>"Alpha", "middle"=>nil, "last"=>"Tracy"},
                   "address"=>{"addressLine1"=>"99704 Emilie Shores", "addressLine2"=>nil, "city"=>"West Tanekaport", "stateCode"=>"OH", "country"=>"US", "zipCode"=>"00013-5566", "zipCodeSuffix"=>nil},
                   "ssn"=>"8682",
                   "vaFileNumber"=>"1360",
                   "dateOfBirth"=>"1928-01-16",
                   "serviceNumber"=>"343163173",
                   "serviceBranch"=>"AIR_FORCE",
                   "phone"=>"7737145581",
                   "email"=>"simon_mann@walsh.test"}},
               "resolution"=>
                {"createdAt"=>"2025-03-27T12:53:17.249Z", "type"=>"decision", "decisionType"=>"declination", "reason"=>"Didn't authorize treatment record disclosure", "creatorId"=>"03e24c1f-1ef8-476b-80c0-532022b6b903", "id"=>"810b554b-478d-42c7-8a5d-d98827add478"},
               "accreditedIndividual"=>{"fullName"=>"Bob Representative", "id"=>"10000"},
               "powerOfAttorneyHolder"=>{"type"=>"veteran_service_organization", "name"=>"Trustworthy Organization", "id"=>"YHZ"}
              }
            ]
          }
        }
      end

      def check_feature_toggle
        unless Flipper.enabled?(:accredited_representative_portal_search, @current_user)
          message = 'The accredited_representative_portal_search feature flag is disabled ' \
                    "for the user with uuid: #{@current_user.uuid}"

          raise Common::Exceptions::Forbidden, detail: message
        end
      end
    end
  end
end
