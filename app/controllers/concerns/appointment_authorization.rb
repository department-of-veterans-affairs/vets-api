# frozen_string_literal: true

module AppointmentAuthorization
  extend ActiveSupport::Concern

  protected

  def authorize
    raise_access_denied unless current_user.loa3?
    raise_access_denied_no_icn if current_user.icn.blank?
  end

  def authorize_with_facilities
    authorize
    raise_access_denied_no_facilities unless current_user.authorize(:vaos, :facilities_access?)
  end

  def raise_access_denied
    raise Common::Exceptions::Forbidden, detail: 'You do not have access to online scheduling'
  end

  def raise_access_denied_no_icn
    raise Common::Exceptions::Forbidden, detail: 'No patient ICN found'
  end

  def raise_access_denied_no_facilities
    raise Common::Exceptions::Forbidden, detail: 'No facility associated with user'
  end
end
