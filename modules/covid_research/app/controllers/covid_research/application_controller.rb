# frozen_string_literal: true

module CovidResearch
  class ApplicationController < ActionController::API
    # protect_from_forgery with: :exception
    before_action :set_tags_and_extra_context

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'coronavirus-research' }
      Raven.tags_context(source: 'coronavirus-research')
    end
  end
end
