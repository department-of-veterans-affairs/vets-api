# frozen_string_literal: true

class AccountLoginStatisticsJob
  include Sidekiq::Worker

  def perform
    total_stats.each do |metric, count|
      StatsD.gauge(metric, count)
    end
  end

  private

  def total_stats
    execute_sql(
      account_login_stats_sql,
      1.year.ago,
      1.month.ago,
      1.week.ago,
      1.day.ago
    ).first
  end

  def execute_sql(sql, *args)
    ActiveRecord::Base.connection_pool.with_connection do |c|
      c.raw_connection.exec_params(sql, args).to_a
    end
  end

  def account_login_stats_sql
    <<-SQL.squish
      SELECT
        #{count_column_sql_statements}
      FROM account_login_stats
    SQL
  end

  def count_column_sql_statements
    SAML::User::LOGIN_TYPES.map do |type|
      %(
        COUNT(#{type}_at) FILTER (WHERE #{type}_at IS NOT NULL) AS "account_login_stats.total_#{type}_accounts",
        COUNT(#{type}_at) FILTER (WHERE #{type}_at > $1) AS "account_login_stats.#{type}_past_year",
        COUNT(#{type}_at) FILTER (WHERE #{type}_at > $2) AS "account_login_stats.#{type}_past_month",
        COUNT(#{type}_at) FILTER (WHERE #{type}_at > $3) AS "account_login_stats.#{type}_past_week",
        COUNT(#{type}_at) FILTER (WHERE #{type}_at > $4) AS "account_login_stats.#{type}_past_day"
      )
    end.join(', ')
  end
end
