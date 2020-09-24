# frozen_string_literal: true

require './rakelib/support/sessions_arg_serializer.rb'

class SessionsFileSerializer < SessionsSerializer
  def initialize(file)
    super
    File.open(file) do |f|
      session_data = JSON.parse(f.read)
      session_data.each { |data| add(data) }
    end
  end

  private

  def add(data)
    uuid = save_session(data['uuid'])
    redis_set(uuid, data['users_b'], data['mvi-profile-response'], data['user_identities'])
  end
end
