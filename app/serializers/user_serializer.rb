# frozen_string_literal: true

require 'backend_services'
require 'common/client/concerns/service_status'

class UserSerializer < ActiveModel::Serializer
  include Common::Client::Concerns::ServiceStatus

  attributes :services, :account, :profile, :va_profile, :veteran_status,
             :in_progress_forms, :prefills_available, :vet360_contact_information,
             :session

  def id
    nil
  end

  def attributes(*args)
    hash = super
    hash[:onboarding] = object.onboarding if object.members.include?(:onboarding)
    hash
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
end
