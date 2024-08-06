require 'fileutils'
require 'active_support/inflector'
require 'pry'

def controller_class_from_path(path)
  path.split('/').map(&:camelize).join('::').gsub('ControllerRb', 'Controller')
end

def update_spec_file(file_path, new_class_name)
  temp_file = "#{file_path}.tmp"

  File.open(temp_file, 'w') do |out_file|
    File.foreach(file_path) do |line|
      if line =~ /RSpec.describe\s+'(.+)',\s+type: :request/
        out_file.puts "RSpec.describe #{new_class_name}, type: :request do"
      else
        out_file.puts line
      end
    end
  end

  FileUtils.mv(temp_file, file_path)
end

def process_spec_file(spec_file_path)
  File.open(spec_file_path) do |file|
    file.each_line do |line|
      if line =~ /RSpec.describe\s+'(.+)',\s+type: :request/
        described_path = $1
        # Translate spec file path to controller path
        controller_path = spec_file_path.sub('spec/requests', 'app/controllers')
                                        .sub('_spec.rb', '.rb')
        controller_class = controller_class_from_path(controller_path)

        # Get the class name from the controller file
        if File.exist?(controller_path)
          File.open(controller_path) do |controller_file|
            controller_file.each_line do |controller_line|
              if controller_line =~ /class\s+(\S+)/
                if $1 != controller_class
                  update_spec_file(spec_file_path, controller_class)
                  puts "Updated: #{spec_file_path}"
                end
                return
              end
            end
          end
        else
          puts "Controller file not found: #{controller_path}"
        end
      end
    end
  end
end

def scan_directory(directory)
  puts "searching directory"
  Dir.glob("#{directory}/**/*_spec.rb").each do |file|
    process_spec_file(file)
  end
end

# modules/accredited_representative_portal/spec/requests/accredited_representative_portal/v0/representative_user_spec.rb
# Directories to scan
request_specs_directory = 'modules/accredited_representative_portal/spec/requests/accredited_representative_portal/v0'
# controller_specs_directory = 'modules/accredited_representative_portal/spec/controllers'

# Scan both directories
scan_directory(request_specs_directory)
# scan_directory(controller_specs_directory)
