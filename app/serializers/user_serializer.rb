# frozen_string_literal: true

require 'backend_services'
require 'common/client/concerns/service_status'

class UserSerializer
  include JSONAPI::Serializer
  include Common::Client::Concerns::ServiceStatus

  set_id { '' }

  attributes :services, :account, :profile, :va_profile, :veteran_status,
             :in_progress_forms, :prefills_available, :vet360_contact_information,
             :session, :onboarding

end
