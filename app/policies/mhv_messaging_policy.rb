# frozen_string_literal: true

MHVMessagingPolicy = Struct.new(:user, :mhv_messaging) do
  def access?(client)
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
