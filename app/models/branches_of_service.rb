# frozen_string_literal: true
require 'common/models/base'

# Cemetery model
class BranchesOfService < Common::Base
  # Cemetery numbers are 3-digits, implying < 1000 in total - we want all of them for populating application forms
  attribute :code, String
  attribute :flat_full_descr, String
  attribute :full_descr, String
  attribute :short_descr, String
  attribute :upright_full_descr, String

  attribute :begin_date, String
  attribute :end_date, String
  attribute :state_required, String

  def id
    code
  end

  def begin_date=(value)
    super(Time.parse(value).utc.strftime('%Y-%m-%d')) if value.is_a?(String)
  end

  def end_date=(value)
    super(Time.parse(value).utc.strftime('%Y-%m-%d')) if value.is_a?(String)
  end

  # Default sort should be by full_descr ascending
  def <=>(other)
    full_descr <=> other.full_descr
  end
end
