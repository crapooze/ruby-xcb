=begin
  This file shows an example of integration of XCB with EventMachine.
Basically, we poll for event on the XCB file descriptor but still process the
events with XCB (when we're sure there's something to process).

=end
$LOAD_PATH.unshift 'lib'

require 'xcb'
require 'eventmachine'

Screen = XCB.struct(:xcb_screen_t)
InternAtomReply = XCB.struct(:xcb_intern_atom_reply_t)

@connection = XCB.connect(nil, 0)
setup = XCB.get_setup(@connection)
p_iterator = XCB.setup_roots_iterator(setup)
@screen = Screen.new(p_iterator)
window = @screen[:root]
@foreground = XCB.generate_id(@connection)
mask = XCB::Constants::GC_FOREGROUND | XCB::Constants::GC_GRAPHICS_EXPOSURES
values = [@screen[:black_pixel], 0]
FFI::MemoryPointer.new(:uint32, values.size) do |ptr|
  ptr.write_array_of_int(values)
  XCB.create_gc(@connection, @foreground, window, mask, ptr)
end
@window = XCB.generate_id(@connection)
mask = XCB::Constants::CW_BACK_PIXEL | XCB::Constants::CW_EVENT_MASK
values = [@screen[:white_pixel], XCB::Constants::EVENT_MASK_EXPOSURE]
FFI::MemoryPointer.new(:uint32, values.size) do |ptr|
  ptr.write_array_of_int(values)
  XCB.create_window(@connection,
                    XCB::Constants::COPY_FROM_PARENT,
                    @window,
                    @screen[:root],
                    0, 0,
                    150, 150,
                    10,
                    XCB::Constants::WINDOW_CLASS_INPUT_OUTPUT,
                    @screen[:root_visual],
                    mask, ptr)
end

XCB.map_window(@connection, @window)
XCB.flush(@connection)

io = IO.for_fd XCB.get_file_descriptor(@connection)

$connection = @connection

module XCB::Evented
  def cookies
    @cookies ||= {}
  end

  def queue
    @queue ||= []
  end

  def manual_event_example
    names = ['name1', 'name2', 'name3']
    names.each do |name|
      request  = ->() {XCB.intern_atom($connection, 0, name.size, name)}
      response = ->(cookie) do 
        ptr = XCB.intern_atom_reply($connection, cookie, nil)
        throw :retry_later unless ptr
        reply = InternAtomReply.new(ptr)
        puts "#{name}: #{reply[:atom]}"
      end
      queue_call(request, response)
    end
  end

  def async_call(req, rsp)
    cookies[req.call] = rsp
  end

  def queue_call(request, response)
    self.notify_writable = true
    queue << [request, response]
  end

  def dequeue_calls!
    until (queue.empty?) do
      req, rsp = queue.shift
      async_call(req, rsp)
    end
    self.notify_writable = false if cookies.empty?
  end

  def check_replies
    puts "checking replies"
    to_delete = []
    cookies.each_pair do |id, handler| 
      catch :retry_later do
        handler.call(id) # if the handler throws :retry_later, then we'll not delete the cookie
        to_delete << id
      end
    end
    to_delete.each{|id| cookies.delete(id)}
    self.notify_writable = false if queue.empty?
  end

  def close
    XCB.disconnect($connection)
    XCB.flush($connection)
    puts "detaching connection"
    detach
  end

  def notify_readable
    ptr = XCB.poll_for_event($connection) 
    if ptr.null? and XCB.connection_has_error($connection)
      close 
    else
      handle_xcb_event(ptr)
    end
  end

  def notify_writable
    dequeue_calls!
    check_replies
  end

  def handle_xcb_event(ptr)
    puts "got event #{ptr} on #{self}"
    manual_event_example
  end
end

EventMachine::run do
  EventMachine.watch(io, XCB::Evented) do |c|
    c.notify_readable = true
    #c.notify_writable = true
  end
end
