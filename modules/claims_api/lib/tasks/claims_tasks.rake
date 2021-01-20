# frozen_string_literal: true

namespace :claims do
  task :export, [:start, :end] => :environment do |task, args|
    start_at = args[:start].present? ? Time.parse(args[:start]) : Time.at(0)
    end_at = args[:end].present? ? Time.parse(args[:end]) : Time.now

    claims = ClaimsApi::AutoEstablishedClaim.where("evss_id is not null")
    claims = claims.where("created_at >= ? and created_at <= ?", start_at, end_at)
    puts 'id,evss_id,has_flashes,has_special_issues'
    claims.each do |claim|
      puts "#{claim.id},#{claim.evss_id},#{claim.flashes.any?},#{claim.special_issues.any?}"
    end
  end
end
