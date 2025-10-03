# frozen_string_literal: true

namespace :sm do
  desc 'set up test users'
  task setup_test_user: :environment do
    user_number = ENV.fetch('user_number', nil)
    mhv_correlation_id = ENV.fetch('mhv_id', nil)
    unless user_number && mhv_correlation_id
      raise 'Run this task like this: bundle exec rake sm:setup_test_user user_number=210 mhv_id=22336066'
    end


    idme_uuid = get_idme_uuid(user_number)
    icn = MPI::Service.new.find_profile_by_identifier(
      identifier: idme_uuid,
      identifier_type: MPI::Constants::IDME_UUID
    )&.profile&.icn

    user_verification = Login::UserVerifier.new(
      login_type: SAML::User::IDME_CSID,
      auth_broker: nil,
      mhv_uuid: nil,
      idme_uuid:,
      dslogon_uuid: nil,
      logingov_uuid: nil,
      icn:
    ).perform

    user_account = user_verification.user_account

    if user_account.needs_accepted_terms_of_use?
      user_account.terms_of_use_agreements.new(
        agreement_version: IdentitySettings.terms_of_use.current_version
      ).accepted!
    end

    cache_mhv_account(icn, mhv_correlation_id)
  end

  def get_idme_uuid(number)
    path = File.join(Settings.betamocks.cache_dir, 'credentials', 'idme', "vetsgovuser#{number}.json")
    json = JSON.parse(File.read(path))
    json['uuid']
  rescue => e
    raise e
  end

  def cache_mhv_account(icn, mhv_correlation_id)
    Rails.cache.write(
      "mhv_account_creation_#{icn}",
      {
        user_profile_id: mhv_correlation_id,
        premium: true,
        champ_va: true,
        patient: true,
        sm_account_created: true,
        message: 'This cache entry was created by rakelib/secure_messaging.rake'
      },
      expires_in: 1.year
    )
  rescue => e
    raise e
  end
end
