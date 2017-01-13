module EducationForm::Forms
  class VA1995 < Base
    TEMPLATE = File.read(File.join(TEMPLATE_PATH, '1995.erb'))
  end
end
