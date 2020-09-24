# frozen_string_literal: true

Dir[File.join(__dir__, 'matchers', '*.rb')].sort.each { |file| require file }
