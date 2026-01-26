# frozen_string_literal: true

namespace :claims do
  task :export, %i[start end] => :environment do |_task, args|
    start_at = args[:start].present? ? Time.parse(args[:start]).utc : Time.at(0).utc
    end_at = args[:end].present? ? Time.parse(args[:end]).utc : Time.now.utc

    claims = ClaimsApi::AutoEstablishedClaim.where.not(evss_id: nil)
    claims = claims.where('created_at >= ? and created_at <= ?', start_at, end_at)
    puts 'id,evss_id,has_flashes,has_special_issues'
    claims.each { |claim| puts "#{claim.id},#{claim.evss_id},#{claim.flashes.any?},#{claim.special_issues.any?}" }
  end
end
