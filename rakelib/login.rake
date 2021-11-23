# frozen_string_literal: true

namespace :login do
  desc 'Login through ID.me as an LOA1 user, then run this task to validate that LOA1 attributes are set properly'
  task :idme_loa_1, [:uuid] => [:environment] do |_, args|
    require 'rainbow'

    @args = args

    def user
      @user ||=
        if @args[:uuid].present?
          User.find(@args[:uuid])
        else
          # Find last logged in user by looking at most recently updated AccountLoginStat
          User.find(AccountLoginStat.last&.account&.idme_uuid) ||
            User.find(AccountLoginStat.last&.account&.logingov_uuid)
        end
    end

    def validate(validation, success_msg, error_msg)
      if validation
        puts Rainbow(success_msg).green
      else
        puts Rainbow(error_msg).red
        exit!(1)
      end
    end

    puts Rainbow('Running login validations...').green

    validate(
      user.present?,
      'Found logged in user',
      'No current user. Please ensure you are logged in with an LOA1 user.'
    )

    validate(
      user.identity&.sign_in&.dig(:service_name) == 'idme',
      'User is logged in with ID.me',
      'User is not logged in with ID.me'
    )

    validate(
      user.idme_uuid == user.account&.idme_uuid,
      'User ID.me UUID matches user account ID.me UUID',
      'User ID.me UUID does not match user account ID.me UUID'
    )

    validate(
      user.logingov_uuid == user.account&.logingov_uuid,
      'User Login.gov UUID matches user account Login.gov UUID',
      'User Login.gov UUID does not match user account Login.gov UUID'
    )

    validate(
      user.loa[:current] == 1,
      'User has an LOA level of 1',
      "This user is LOA1 but has an LOA level of #{user.loa[:current]}"
    )

    validate(
      user.ssn.blank?,
      'User does not have SSN',
      'User has SSN. LOA1 users should not have a SSN'
    )

    idme_login_time = user.account&.login_stats&.idme_at
    validate(
      idme_login_time.present? && idme_login_time > 15.minutes.ago,
      'User account login stats incremented correctly',
      'User account login stats were not updated correctly'
    )

    puts Rainbow('All LOA1 validations pass!').green
  end
end
