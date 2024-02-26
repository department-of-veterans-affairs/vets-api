# frozen_string_literal: true

module Vye
  class Vye::Verification < ApplicationRecord
    belongs_to :user_info

    validates(:source_ind, presence: true)

    enum source_ind: { web: 'W', phone: 'P' }

    scope :created_today, -> { includes(:user_info).where('created_at >= ?', Time.zone.now.beginning_of_day) }

    def self.todays_verifications
      created_today.each_with_object([]) do |record, result|
        result << {
          stub_nm: record.user_info.stub_nm,
          ssn: record.user_info.ssn,
          transact_date: record.created_at.strftime('%Y%m%d'),
          rpo_code: record.user_info.rpo_code,
          indicator: record.user_info.indicator,
          source_ind: record.source_ind
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
