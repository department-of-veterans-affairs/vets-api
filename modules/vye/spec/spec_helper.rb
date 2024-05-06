# frozen_string_literal: true

Vye::Engine.root.glob('spec/support/**/*').each { |f| require f if f.file? }
