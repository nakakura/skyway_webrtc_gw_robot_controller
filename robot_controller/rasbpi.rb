#!/usr/bin/ruby
require "socket"
require "observer"
#require "pi_piper"

#GPIO_16 = PiPiper::Pin.new(:pin => 16, :direction => :out)
#GPIO_20 = PiPiper::Pin.new(:pin => 20, :direction => :out)
#GPIO_21 = PiPiper::Pin.new(:pin => 21, :direction => :out)
# GPIO_13 = PiPiper::Pin.new(:pin => 13, :direction => :out)
# GPIO_19 = PiPiper::Pin.new(:pin => 19, :direction => :out)
# GPIO_26 = PiPiper::Pin.new(:pin => 26, :direction => :out)

class State
  NOT_OVERRRIDE = 'not override error'
  def pin()
    raise State::NOT_OVERRRIDE
  end

  def update(flag)
    raise DayOfTheWeek::NOT_OVERRRIDE
  end
end

class Forward < State
  def pin()
    return "forward"
  end

  def update(flag)
    if flag == 0
      Stop.new
    elsif flag == -1
      Backward.new
    end
  end
end

class Backward < State
  def pin()
    return "backward"
  end

  def update(flag)
    if flag == 0
      Stop.new
    elsif flag == 1
      Forward.new
    end
  end
end

class Stop < State
  def pin()
    return "stop"
  end

  def update(flag)
    if flag == 1
      Forward.new
    elsif flag == -1
      Backward.new
    end
  end
end

class StateManager
  include Observable

  def initialize()
    @body_state = Stop.new
    @leg_state = Stop.new
  end

  def format(message)
    array = message.split(",")
    key = array[0].to_i
    value = array[1].to_f

    if value < -0.5
      [key, 1]
    elsif value > 0.5
      [key, -1]
    else
      [key, 0]
    end
  end

  def feed(message)
    (key, value) = self.format(message)

    if key == 0
      new_state = @body_state.update(value)
      if new_state
        changed
        @body_state = new_state
        notify_observers(key, new_state.pin())
      end
    elsif key == 1
      new_state = @leg_state.update(value)
      if new_state
        changed
        @leg_state = new_state
        notify_observers(key, new_state.pin())
      end
    end
  end
end

class Pin
  def update(key, pin)
    p key
    p pin
  end
end

if __FILE__ == $0
  stateManager = StateManager.new
  pin = Pin.new
  stateManager.add_observer(pin)

  udps = UDPSocket.open()
  udps.bind("0.0.0.0", 10000)

  loop do
    data = udps.recv(65535).chomp
    stateManager.feed(data)
  end

  udps.close
end
