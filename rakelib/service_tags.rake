# frozen_string_literal: true

namespace :service_tags do
  desc 'List all routable controller files, their class names, and all their ancestors'
  task lint: :environment do
    def fileclass(controller)
      file = "#{controller}_controller"
      c = file.split('/').map(&:camelize).join('::')
      return [file, c]
    end
    
    def routable_controllers
      result = []
      all_controllers = Rails.application.routes.routes.map do |route|
        route.defaults[:controller]
      end.uniq.compact
      
      controllers = all_controllers.reject { |x| x =~ /active_storage|rails|action_mailbox|devise|service_worker/ }
      
      controllers.each do |c|
        file, klass = fileclass(c)
        result << [file, klass]
      end
      
      Rails::Engine.subclasses.each do |engine|
        englist = engine.routes.routes.map(&:defaults).map{|x|x[:controller]}.uniq
        englist.each do |c|
          file, klass = fileclass(c)
          result << [file, klass]
        end
      end
      result
    end
    
    def implements_traceable?(klass)
      return false unless klass.include? Traceable
      return false if klass.trace_service_tag.nil?
      
      true
    end
    
    non_compliant_controllers = []
    
    routable_controllers.each do |(_file, klass_str)|
      klass = klass_str.constantize
      unless implements_traceable?(klass)
        non_compliant_controllers << klass_str
      end
    end
    
    if non_compliant_controllers.any?
      puts "The following controllers have not implemented set_trace_tags correctly from the Traceable concern:"
      non_compliant_controllers.each do |controller|
        puts "- #{controller}"
      end
    else
      puts "All controllers have implemented set_trace_tags correctly."
    end
    
    puts "\nTotal Controllers Checked: #{routable_controllers.count}"
  end
end
