# frozen_string_literal: true

# Minimal test helpers for SRE RuboCop cops.
# Intentionally self-contained to avoid rubocop/rspec/support which
# pollutes global RSpec scope (leaks `let(:config)` into all specs).
module SreCopSpecHelper
  def inspect_source(source, file_path = '(string)')
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
    commissioner = RuboCop::Cop::Commissioner.new([cop])
    result = commissioner.investigate(processed_source)
    result.offenses
  end

  def expect_no_offenses(source, file_path = '(string)')
    offenses = inspect_source(source, file_path)
    expect(offenses).to be_empty
  end
end
