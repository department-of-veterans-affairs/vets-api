# frozen_string_literal: true

class ServiceAuthDetail
  include ActiveModel::Serialization

  attr_accessor :is_authorized, :policy, :policy_action, :errors

  def initialize(user, params)
    @policy = params[:policy].to_sym
    @policy_action = "#{params[:policy_action]}?".to_sym
    @is_authorized = user.authorize(@policy, @policy_action)
    @errors = user.authorize_errors(@policy, @policy_action)
  end
end
