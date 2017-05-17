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
      raise Common::Exceptions::RecordNotFound, params[:name] unless resource.present?
      render(
        json: resource,
        serializer: TermsAndConditionsSerializer
      )
    end

    def latest_user_data
      resource = TermsAndConditionsAcceptance.for_user(current_user).for_terms(params[:name]).for_latest
      raise Common::Exceptions::RecordNotFound, params[:name] unless resource.present?
      render(
        json: resource,
        serializer: TermsAndConditionsAcceptanceSerializer
      )
    end

    def accept_latest
      terms = TermsAndConditions.where(name: params[:name]).latest
      raise Common::Exceptions::RecordNotFound, params[:name] unless terms.present?
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
