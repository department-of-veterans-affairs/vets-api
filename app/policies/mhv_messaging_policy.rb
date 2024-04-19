# frozen_string_literal: true

require 'sm/client'

MHVMessagingPolicy = Struct.new(:user, :mhv_messaging) do
  def access?
    return false unless user.mhv_correlation_id

    client = SM::Client.new(session: { user_id: user.mhv_correlation_id })
    validate_client(client)
  end

  def mobile_access?
    return false unless user.mhv_correlation_id

    client = Mobile::V0::Messaging::Client.new(session: { user_id: user.mhv_correlation_id })
    validate_client(client)
  end

  private

  def validate_client(client)
    if client.session.expired?
      client.authenticate
      !client.session.expired?
    else
      true
    end
  rescue
    false
  end
end
