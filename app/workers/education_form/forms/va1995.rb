module EducationForm::Forms
  class VA1995 < Base
    TEMPLATE = File.read(File.join(TEMPLATE_PATH, '1995.erb'))
    TYPE = '22-1995'
  end
end
