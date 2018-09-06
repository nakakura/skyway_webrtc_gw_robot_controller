#!/usr/bin/ruby
require "socket"
require "observer"
require "pi_piper"

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
  def initialize(pin1, pin2)
    @pin1 = pin1
    @pin2 = pin2
  end

  def pin()
    @pin1.off
    @pin2.on
  end

  def update(flag)
    if flag == 0
      Stop.new(@pin1, @pin2)
    elsif flag == -1
      Backward.new(@pin1, @pin2)
    end
  end
end

class Backward < State
  def initialize(pin1, pin2)
    @pin1 = pin1
    @pin2 = pin2
  end

  def pin()
    @pin1.on
    @pin2.off
  end

  def update(flag)
    if flag == 0
      Stop.new(@pin1, @pin2)
    elsif flag == 1
      Forward.new(@pin1, @pin2)
    end
  end
end

class Stop < State
  def initialize(pin1, pin2)
    @pin1 = pin1
    @pin2 = pin2
  end

  def pin()
    @pin1.off
    @pin2.off
  end

  def update(flag)
    if flag == 1
      Forward.new(@pin1, @pin2)
    elsif flag == -1
      Backward.new(@pin1, @pin2)
    end
  end
end

class StateManager
  include Observable

  def initialize()
    gpio_in1 = PiPiper::Pin.new(:pin => 26, :direction => :out)
    gpio_in2 = PiPiper::Pin.new(:pin => 19, :direction => :out)
    gpio_in3 = PiPiper::Pin.new(:pin => 20, :direction => :out)
    gpio_in4 = PiPiper::Pin.new(:pin => 21, :direction => :out)

    @body_state = Stop.new(gpio_in1, gpio_in2)
    @leg_state = Stop.new(gpio_in3, gpio_in4)
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

if __FILE__ == $0
  stateManager = StateManager.new

  udps = UDPSocket.open()
  udps.bind("0.0.0.0", 10000)

  loop do
    data = udps.recv(65535).chomp
    stateManager.feed(data)
  end

  udps.close
end
