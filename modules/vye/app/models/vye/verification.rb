# frozen_string_literal: true

module Vye
  class Vye::Verification < ApplicationRecord
    self.ignored_columns += [:user_info_id]

    belongs_to :user_profile
    belongs_to :award, optional: true

    validates(:source_ind, presence: true)

    enum(
      source_ind: { web: 'W', phone: 'P' },
      _prefix: :source
    )

    def self.todays_verifications
      UserInfo
        .includes(:bdn_clone, awards: :verifications)
        .each_with_object([]) do |user_info, result|
          verification = user_info.queued_verifications.first

          stub_nm = user_info.stub_nm
          ssn = user_info.ssn
          transact_date = verification.transact_date.strftime('%Y%m%d')
          rpo_code = user_info.rpo_code
          indicator = user_info.indicator
          source_ind = verification.source_ind

          result << { stub_nm:, ssn:, transact_date:, rpo_code:, indicator:, source_ind: }
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
