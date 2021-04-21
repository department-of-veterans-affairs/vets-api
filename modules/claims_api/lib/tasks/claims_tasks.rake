# frozen_string_literal: true

namespace :claims do
  task :export, %i[start end] => :environment do |_task, args|
    start_at = args[:start].present? ? Time.parse(args[:start]).utc : Time.at(0).utc
    end_at = args[:end].present? ? Time.parse(args[:end]).utc : Time.now.utc

    claims = ClaimsApi::AutoEstablishedClaim.where('evss_id is not null')
    claims = claims.where('created_at >= ? and created_at <= ?', start_at, end_at)
    puts 'id,evss_id,has_flashes,has_special_issues'
    claims.each { |claim| puts "#{claim.id},#{claim.evss_id},#{claim.flashes.any?},#{claim.special_issues.any?}" }
  end

  task update_poa_md5: :environment do
    power_of_attorneys = ClaimsApi::PowerOfAttorney.all
    # save! reruns validations, which includes set_md5
    power_of_attorneys.each(&:save!)
  end
end
