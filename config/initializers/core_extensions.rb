Dir[File.join(Rails.root, "lib", "core_extensions", "*.rb")].each {|l| require l }
