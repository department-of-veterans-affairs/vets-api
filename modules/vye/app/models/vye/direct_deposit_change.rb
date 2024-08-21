# frozen_string_literal: true

module Vye
  class Vye::DirectDepositChange < ApplicationRecord
    belongs_to :user_info

    ENUM_ACCT_TYPE = ActiveSupport::HashWithIndifferentAccess.new(checking: 'C', savings: 'S')

    has_kms_key

    has_encrypted(
      :acct_no, :acct_type, :bank_name, :bank_phone, :email,
      :full_name, :routing_no, :phone, :phone2,
      key: :kms_key, **lockbox_options
    )

    validates(
      :acct_no, :acct_type, :bank_name, :bank_phone, :email,
      :full_name, :routing_no, :phone,
      presence: true
    )

    # can't make acct_type an enum because it's encrypted
    validate :acct_type_in_enum

    def self.acct_types = ENUM_ACCT_TYPE

    def acct_type_in_enum
      space = self.class.acct_types.keys
      errors.add(:field_name, 'must be either checking, or savings') unless acct_type.in?(space)
    end

    def routing_no_body
      routing_no[0..7]
    end

    def routing_no_chk
      routing_no[8]
    end

    scope :export_ready, lambda {
      self
        .select('DISTINCT ON (vye_direct_deposit_changes.user_info_id) vye_direct_deposit_changes.*')
        .joins(user_info: :bdn_clone)
        .where(vye_bdn_clones: { export_ready: true })
        .order('vye_direct_deposit_changes.user_info_id, vye_direct_deposit_changes.created_at DESC')
    }

    def self.dashed_triples_format(phone_number)
      return if phone_number.blank?

      phone_number
        .gsub(/\D/, '')
        .gsub(
          /(\d{3})(\d{3})(\d+)/,
          '\1-\2-\3'
        )
    end

    def self.each_report_row
      return to_enum(:each_report_row) unless block_given?

      export_ready.in_batches(of: 1000) do |batch|
        batch.each do |record|
          user_info = record.user_info

          yield({
            rpo: user_info.rpo_code,
            ben_type: user_info.indicator,
            ssn: user_info.ssn,
            file_number: user_info.file_number,
            full_name: record.full_name,
            phone: dashed_triples_format(record.phone.presence),
            phone2: dashed_triples_format(record.phone2.presence),
            email: record.email,
            acct_no: record.acct_no,
            acct_type: acct_types[record.acct_type],
            routing_no: record.routing_no_body,
            chk_digit: record.routing_no_chk,
            bank_name: record.bank_name,
            bank_phone: dashed_triples_format(record.bank_phone)
          }.transform_values { |v| v.presence || ' ' })
        end
      end
    end

    REPORT_TEMPLATE =
      <<~END_OF_TEMPLATE.gsub(/\n/, '')
        %-3<rpo>s,
        %-1<ben_type>s,
        %-9<ssn>s,
        %-9<file_number>s,
        %-20<full_name>s,
        %<phone>s,
        %<phone2>s,
        %<email>s,
        %<acct_no>s,
        %-1<acct_type>s,
        %<routing_no>s,
        %-1<chk_digit>s,
        %<bank_name>s,
        %<bank_phone>s
      END_OF_TEMPLATE

    private_constant :REPORT_TEMPLATE

    def self.write_report(io)
      each_report_row do |row|
        io.puts(format(REPORT_TEMPLATE, row))
      end
    end
  end
end
