# frozen_string_literal: true

module Vye
  class Vye::Verification < ApplicationRecord
    belongs_to :user_profile
    belongs_to :user_info, optional: true
    belongs_to :award, optional: true

    validates(:source_ind, presence: true)

    enum :source_ind, { web: 'W', phone: 'P' }, prefix: :source

    scope :export_ready, lambda {
      self
        .select('DISTINCT ON (vye_verifications.user_info_id) vye_verifications.*')
        .joins(user_info: :bdn_clone)
        .where(vye_bdn_clones: { export_ready: true })
        .order('vye_verifications.user_info_id, vye_verifications.created_at DESC')
    }

    def self.each_report_row
      return to_enum(:each_report_row) unless block_given?

      export_ready.in_batches(of: 1000) do |batch|
        batch.each do |record|
          user_info = record.user_info

          yield({
            stub_nm: user_info.stub_nm,
            td_number: user_info.td_number,
            transact_date: record.transact_date.strftime('%Y%m%d'),
            rpo_code: user_info.rpo_code,
            indicator: user_info.indicator,
            source_ind: source_inds[record.source_ind]
          })
        end
      end
    end

    REPORT_TEMPLATE =
      YAML.load(<<-END_OF_TEMPLATE).gsub(/\n/, '')
      |-
        %-7<stub_nm>s
        %-9<td_number>s
        %-8<transact_date>s
        %-3<rpo_code>s
        %-1<indicator>s
        %-1<source_ind>s
      END_OF_TEMPLATE

    private_constant :REPORT_TEMPLATE

    def self.write_report(io)
      each_report_row do |row|
        io.puts(format(REPORT_TEMPLATE, row))
      end
    end
  end
end
