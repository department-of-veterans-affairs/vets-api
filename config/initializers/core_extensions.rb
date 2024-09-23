# frozen_string_literal: true

Dir[Rails.root.join('lib', 'core_extensions', '*.rb').to_s].each { |l| require l }
