# This is an example model. Check out the spec!
# Then delete it when you're ready to start.
class Roadrunner
  def greeting(times = 1)
    return "beep beep" if times == 1
    "beep beep, " * times
  end
end
