# frozen_string_literal: true

RSpec::Matchers.define_negated_matcher :not_trigger_statsd_increment, :trigger_statsd_increment
RSpec::Matchers.define_negated_matcher :not_trigger_statsd_measure, :trigger_statsd_measure
RSpec::Matchers.define_negated_matcher :not_change, :change
