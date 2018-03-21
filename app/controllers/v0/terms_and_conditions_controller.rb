# frozen_string_literal: true

module V0
  class TermsAndConditionsController < ApplicationController
    include ActionController::Serialization

    def index
      resource = TermsAndConditions.all.select(:id, :name, :version, :updated_at, :created_at)
      resource = [] if resource.none?
      render(
        json: resource,
        serializer: CollectionSerializer,
        each_serializer: TermsAndConditionsMiniSerializer
      )
    end

    def latest
      resource = TermsAndConditions.where(name: params[:name]).latest
      raise Common::Exceptions::RecordNotFound, params[:name] if resource.blank?
      render(
        json: resource,
        serializer: TermsAndConditionsSerializer
      )
    end

    def latest_user_data
      terms = TermsAndConditions.where(name: params[:name]).latest
      raise Common::Exceptions::RecordNotFound, params[:name] if terms.blank?
      resource = terms.acceptances.for_user(current_user).first
      raise Common::Exceptions::RecordNotFound, current_user.uuid if resource.blank?
      render(
        json: resource,
        serializer: TermsAndConditionsAcceptanceSerializer
      )
    end

    def accept_latest
      terms = TermsAndConditions.where(name: params[:name]).latest
      raise Common::Exceptions::RecordNotFound, params[:name] if terms.blank?
      resource = TermsAndConditionsAcceptance.new(
        user_uuid: current_user.uuid,
        terms_and_conditions: terms
      )
      if resource.save
        render(
          json: resource,
          serializer: TermsAndConditionsAcceptanceSerializer
        )
      else
        raise Common::Exceptions::ValidationErrors, resource
      end
    end
  end
end
