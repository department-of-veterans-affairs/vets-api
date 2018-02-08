# frozen_string_literal: true

class Authorization
  attr_writer :user

  MHV_BASED_SERVICES = %w[rx messaging health-records].freeze
  EVSS_CLAIMS = 'evss-claims'
  APPEALS_STATUS = 'appeals-status'
  USER_PROFILE = 'user-profile'
  ID_CARD = 'id-card'
  IDENTITY_PROOFED = 'identity-proofed'

  def initialize(user)
    @user = user
  end

  def authorized?(policy, method)
    Pundit.policy!(@user, policy).send(method)
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def authorized_services
    service_list = %w[facilities hca edu-benefits form-save-in-progress form-prefill]
    service_list += MHV_BASED_SERVICES if authorized? :mhv, :account_eligible?
    service_list << EVSS_CLAIMS if authorized? :evss, :access?
    service_list << USER_PROFILE if authorized? :profile, :read?
    service_list << APPEALS_STATUS if authorized? :appeals, :access?
    service_list << ID_CARD if authorized? :id_card, :access?
    service_list << IDENTITY_PROOFED if authorized? :profile, :identity_proofed?
    service_list
  end
  # rubocop:enable Metrics/CyclomaticComplexity
end
