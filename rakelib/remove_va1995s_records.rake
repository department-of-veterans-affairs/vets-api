# frozen_string_literal: true

namespace :VA1995s do
  desc 'Remove temporary/stale records no longer in use'
  task remove_old_records: :environment do
    SavedClaim.where(type: 'SavedClaim::EducationBenefits::VA1995s').delete_all
  end
end
