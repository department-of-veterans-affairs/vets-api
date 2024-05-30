# frozen_string_literal: true

module Vye
  class Vye::AddressChange < ApplicationRecord
    belongs_to :user_info

    has_kms_key

    has_encrypted(
      :veteran_name,
      :address1, :address2, :address3, :address4, :address5,
      :city, :state, :zip_code,
      key: :kms_key, **lockbox_options
    )

    validates(:origin, presence: true)

    validates(
      :veteran_name, :address1, :city,
      presence: true, if: -> { origin == 'frontend' }
    )

    # The 'cached' enum is a special case where the record was created on the frontend
    # and sent to the backend, but the backend has not yet processed it.
    # So it will not have been reflected from the backend until the next pull.
    enum(
      origin: { frontend: 'frontend', cached: 'cached', backend: 'backend', expired: 'expired' },
      _suffix: true
    )

    scope :created_today, lambda {
      includes(user_info: :user_profile)
        .where('created_at >= ?', Time.zone.now.beginning_of_day)
    }

    def self.todays_records
      created_today.each_with_object([]) do |record, result|
        result << {
          rpo: record.user_info.rpo_code,
          benefit_type: record.user_info.indicator,
          ssn: record.user_info.ssn,
          file_number: record.user_info.file_number,
          veteran_name: record.veteran_name,
          address1: record.address1,
          address2: record.address2,
          address3: record.address3,
          address4: record.address4,
          city: record.city,
          state: record.state,
          zip_code: record.zip_code
        }
      end
    end

    def self.todays_report
      template = YAML.load(<<-END_OF_TEMPLATE).gsub(/\n/, '')
      |-
        %3<rpo>s,
        %1<benefit_type>s,
        %9<ssn>s,
        %9<file_number>s,
        %20<veteran_name>s,
        %<address1>s,
        %<address2>s,
        %<address3>s,
        %<address4>s,
        %<city>s,
        %6<state>s,
        %5<zip_code>s
      END_OF_TEMPLATE

      report = todays_records.each_with_object([]) do |record, result|
        result << format(template, record)
      end

      report.join("\n")
    end
  end
end
