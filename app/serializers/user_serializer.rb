# frozen_string_literal: true

require 'backend_services'
require 'common/client/concerns/service_status'

class UserSerializer < ActiveModel::Serializer
  include Common::Client::Concerns::ServiceStatus

  attributes :services, :account, :profile, :va_profile, :veteran_status,
             :in_progress_forms, :prefills_available, :vet360_contact_information,
             :session, :onboarding

  def id
    nil
  end

  delegate :account, to: :object
  delegate :profile, to: :object
  delegate :vet360_contact_information, to: :object
  delegate :va_profile, to: :object
  delegate :veteran_status, to: :object
  delegate :in_progress_forms, to: :object
  delegate :prefills_available, to: :object
  delegate :services, to: :object
  delegate :session, to: :object
  delegate :onboarding, to: :object
end
