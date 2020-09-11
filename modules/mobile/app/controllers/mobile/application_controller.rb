# frozen_string_literal: true

module Mobile
  class ApplicationController < BaseApplicationController
    before_action :check_feature_flag, :authenticate

    TOKEN_REGEX = /Bearer /.freeze

    private
    
    def check_feature_flag
      return nil if Flipper.enabled?(:mobile_api)

      message = {
        errors: [
          {
            title: 'Not found',
            detail: 'There are no routes matching your request',
            code: '411',
            status: '404'
          }
        ]
      }

      render json: message, status: :not_found
    end
    
    def authenticate
      raise Common::Exceptions::Forbidden.new(detail: 'Missing bearer auth token') if auth_token.nil?
      @session_object = IAMSSOeSession.find(auth_token)
      
      service = VAOS::AppointmentService.facilities

      if @session_object.nil?
        iam_ssoe_user_traits = iam_ssoe_service.post_introspect(auth_token)
        @user_identity = UserIdentity.new(normalize_traits(iam_ssoe_user_traits))
        # @current_user =
      else
        @current_user = User.find(@session_object.uuid)
      end
    end
    
    def auth_token
      @auth_token ||= request.authorization.to_s[TOKEN_REGEX]
    end
    
    def iam_ssoe_service
      IAMSSOeOAuth::Service.new
    end
    
    def normalize_traits(traits)
      {
        uuid: traits[:email],
        email: traits[:email],
        first_name: traits[:email],
        middle_name: traits[:email],
        last_name: traits[:email],
        common_name: traits[:email],
        gender: traits[:email],
        birth_date: traits[:email],
        zip: traits[:email],
        ssn: traits[:email],
        loa: traits[:email],
        multifactor: traits[:email], # used by F/E to decision on whether or not to prompt user to add MFA
        authn_context: traits[:email], # used by F/E to handle various identity related complexities pending refactor
        idme_uuid: traits[:email],
        sec_id: traits[:email],
        mhv_icn:  traits[:email],# only needed by B/E not serialized in user_serializer
        mhv_correlation_id:  traits[:email], # this is the cannonical version of MHV Correlation ID, provided by MHV sign-in users
        mhv_account_type:  traits[:email], # this is only available for MHV sign-in users
        dslogon_edipi:  traits[:email], # this is only available for dslogon users
        sign_in:, Hash  traits[:email], # original sign_in (see sso_service#mergable_identity_attributes)
        authenticated_by_ssoe: traits[:email]
      }
    end
  end
end

def self.build_from_okta_profile(uuid:, profile:, ttl:)
  identity = new(
    uuid: uuid,
    email: profile['email'],
    first_name: profile['firstName'],
    middle_name: profile['middleName'],
    last_name: profile['lastName'],
    mhv_icn: profile['icn'],
    loa: profile.derived_loa
  )
  identity.expire(ttl)
  identity
end

validates :uuid, presence: true
validates :loa, presence: true
validate  :loa_highest_present