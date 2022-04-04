# frozen_string_literal: true

require 'inherited_proofing/mhv/inherited_proofing_verifier'
require 'inherited_proofing/logingov/service'

class InheritedProofingController < ApplicationController
  def auth
    auth_code = InheritedProofing::MHV::InheritedProofingVerifier.new(@current_user).perform
    raise unless auth_code

    render body: logingov_inherited_proofing_service.render_auth(auth_code: auth_code),
           content_type: 'text/html'
  rescue => e
    render json: { errors: e }, status: :bad_request
  end

  private

  def logingov_inherited_proofing_service
    @logingov_inherited_proofing_service ||= InheritedProofing::Logingov::Service.new
  end
end
