# frozen_string_literal: true

module Vye
  class Vye::Verification < ApplicationRecord
    belongs_to :user_profile
    belongs_to :award, optional: true

    validates(:source_ind, presence: true)

    enum source_ind: { web: 'W', phone: 'P' }

    def self.todays_verifications
      UserInfo
        .joins(awards: :verifications)
        .includes(awards: :verifications)
        .distinct
        .each_with_object([]) do |user_info, result|
          verification = user_info.awards.map(&:verifications).flatten.first
          result << {
            stub_nm: user_info.stub_nm,
            ssn: user_info.ssn,
            transact_date: verification.created_at.strftime('%Y%m%d'),
            rpo_code: user_info.rpo_code,
            indicator: user_info.indicator,
            source_ind: verification.source_ind
          }
        end
    end

    def self.todays_verifications_report
      report = todays_verifications.each_with_object([]) do |record, result|
        result << format(
          '%7<stub_nm>s%9<ssn>s%8<transact_date>s%3<rpo_code>s%1<indicator>s%1<source_ind>s',
          record
        )
      end

      report.join("\n")
    end
  end
end
