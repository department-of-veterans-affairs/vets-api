# frozen_string_literal: true

namespace :VA526ez_submit_transaction do
  desc 'Rotate the encryption keys'
  task remove_old_data: :environment do
    AsyncTransaction::Base.where(type: 'AsyncTransaction::EVSS::VA526ezSubmitTransaction').delete_all
  end
end
