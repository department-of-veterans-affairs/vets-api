# frozen_string_literal: true

FactoryBot.define do
  factory :openid_user, class: 'OpenidUser' do
    transient do
      identity_attrs nil
    end

    uuid 'b2fab2b5-6af0-45e1-a9e2-394347af91ef'
    last_signed_in Time.now.utc

    callback(:after_build, :after_stub) do |user, t|
      if t.identity_attrs
        # Normally the identity attribute would be set by looking up a previously-saved identity.
        # This is a conventience method for allowing the identity to be constructed and associated
        # with the user without having to save it.
        user.instance_variable_set(:@identity, OpenidUserIdentity.create(t.identity_attrs))
      end
    end
  end
end
