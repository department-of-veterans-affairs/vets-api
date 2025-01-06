# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../rakelib/piilog_repl/piilog_helpers'

Q = PersonalInformationLogQueryBuilder

describe PersonalInformationLogQueryBuilder do
  [
    [
      'string/symbol args* narrow the error_class (*most string args)',
      Q.call(:hlr, :nod),
      'SELECT "personal_information_logs".* FROM "personal_information_logs"' \
      " WHERE (error_class ILIKE ANY (array['%hlr%', '%nod%']))"
    ],
    [
      'a single date narrows the query to just that day',
      Q.call(:hlr, '2021-04-01'),
      'SELECT "personal_information_logs".* FROM "personal_information_logs"' \
      " WHERE (error_class ILIKE ANY (array['%hlr%']))" \
      " AND \"personal_information_logs\".\"created_at\" BETWEEN '2021-04-01 00:00:00' AND '2021-04-01 23:59:59.999999'"
    ],
    [
      'can take a date range, and does first_time.start_of_day second_time.end_of_day',
      Q.call('2021-03-01', '2021-03-31'),
      'SELECT "personal_information_logs".* FROM "personal_information_logs" WHERE' \
      ' "personal_information_logs"."created_at" BETWEEN \'2021-03-01 00:00:00\' AND \'2021-03-31 23:59:59.999999\''
    ],
    [
      "argument order doesn't matter (2 time arguments can be specified --unrelated args can be inbetween them)",
      Q.call('2021-03-01', :hlr, '2021-03-31'),
      'SELECT "personal_information_logs".* FROM "personal_information_logs"' \
      " WHERE (error_class ILIKE ANY (array['%hlr%']))" \
      " AND \"personal_information_logs\".\"created_at\" BETWEEN '2021-03-01 00:00:00' AND '2021-03-31 23:59:59.999999'"
    ],
    [
      'specific times/dates are allowed',
      Q.call('2021-03-01T12:00Z', Time.zone.parse('2021-04-01T14:00:00Z') - 5.minutes),
      'SELECT "personal_information_logs".* FROM "personal_information_logs" WHERE' \
      " \"personal_information_logs\".\"created_at\" BETWEEN '2021-03-01 12:00:00' AND '2021-04-01 13:55:00'"
    ],
    [
      'durations are allowed',
      Q.call(30.days, '2021-03-01'), # 30 days before March 1
      'SELECT "personal_information_logs".* FROM "personal_information_logs"' \
      ' WHERE "personal_information_logs"."created_at"' \
      " BETWEEN '2021-01-30 23:59:59.999999' AND '2021-03-01 23:59:59.999999'"
    ],
    [
      'times ranges can be open ended with nil',
      Q.call('2021-03-01', nil),
      'SELECT "personal_information_logs".* FROM "personal_information_logs"' \
      " WHERE (created_at >= '2021-03-01 00:00:00')"
    ],
    [
      'kwargs work like a normal "where" call',
      Q.call(:hlr, updated_at: ['2021-04-02'.in_time_zone.all_day]),
      'SELECT "personal_information_logs".* FROM "personal_information_logs"' \
      ' WHERE "personal_information_logs"."updated_at" BETWEEN' \
      " '2021-04-02 00:00:00' AND '2021-04-02 23:59:59.999999' AND (error_class ILIKE ANY (array['%hlr%']))"
    ]

  ].each do |desc, relation, expected_sql|
    it(desc) { expect(relation.to_sql).to eq expected_sql }
  end
end
