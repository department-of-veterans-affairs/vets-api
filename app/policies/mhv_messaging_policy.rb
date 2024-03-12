# frozen_string_literal: true

MHVMessagingPolicy = Struct.new(:user, :mhv_messaging) do
  def access?(client)
    client.authenticate if client.session.expired?
    !client.session.expired?
  rescue
    false
  end
end
