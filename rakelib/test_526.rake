# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
require_relative 'support/disability_compensation_form/setup_test'

namespace :test_526 do

  desc 'test submit endpoint'
  task :submit, [:env, :user_token, :times_to_run] do |_, args|

    st = SetupTest.new(args[:env], args[:user_token], args[:times_to_run].to_i)

    st.create_itf unless st.active_itf?
    st.submit
  end
end
