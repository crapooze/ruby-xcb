=begin
  This file is an equivalent of the XCB tutorial about basic windows and drawing.
  http://xcb.freedesktop.org/tutorial/basicwindowsanddrawing/
=end
$LOAD_PATH.unshift 'lib'

require 'xcb'

Screen = XCB.struct(:xcb_screen_t)
Point = XCB.struct(:xcb_point_t)
Segment = XCB.struct(:xcb_segment_t)
Rectangle = XCB.struct(:xcb_rectangle_t)
Arc = XCB.struct(:xcb_arc_t)
GenericEvent = XCB.struct(:xcb_generic_event_t)

points_coord = [[10, 10], [10, 20], [20, 10], [20, 20]]
lines_coord = [[50,10], [5, 20], [25, 25], [10, 10]]
segments_coord = [[100, 10, 140, 30], [80, 50, 10, 40]]
rectangles_coord = [[10, 50, 40, 20], [80, 50, 10, 40]]
arcs_coord = [[10, 100, 60, 40, 0, 90 << 6], [90, 100, 55, 40, 0, 270 << 6]]

points = FFI::MemoryPointer.new(Point, points_coord.size)
points_coord.each_with_index do |ary, idx|
  pt = Point.new(points[idx])
  pt[:x] = ary[0]
  pt[:y] = ary[1]
end

lines = FFI::MemoryPointer.new(Point, lines_coord.size)
lines_coord.each_with_index do |ary, idx|
  pt = Point.new(lines[idx])
  pt[:x] = ary[0]
  pt[:y] = ary[1]
end

segments = FFI::MemoryPointer.new(Segment, lines_coord.size)
segments_coord.each_with_index do |ary, idx|
  seg = Segment.new(segments[idx])
  seg[:x1] = ary[0]
  seg[:y1] = ary[1]
  seg[:x2] = ary[2]
  seg[:y2] = ary[3]
end

rectangles = FFI::MemoryPointer.new(Rectangle, lines_coord.size)
rectangles_coord.each_with_index do |ary, idx|
  seg = Rectangle.new(rectangles[idx])
  seg[:x] = ary[0]
  seg[:y] = ary[1]
  seg[:width] = ary[2]
  seg[:height] = ary[3]
end

arcs = FFI::MemoryPointer.new(Arc, lines_coord.size)
arcs_coord.each_with_index do |ary, idx|
  seg = Arc.new(arcs[idx])
  seg[:x] = ary[0]
  seg[:y] = ary[1]
  seg[:width] = ary[2]
  seg[:height] = ary[3]
  seg[:angle1] = ary[3]
  seg[:angle2] = ary[3]
end


# Open the connection to the X server
@connection = XCB.connect(nil, 0)

# Get the first screen
#XXX look at the .data issue
setup = XCB.get_setup(@connection)
p_iterator = XCB.setup_roots_iterator(setup)

@screen = Screen.new(p_iterator) #we pick the 1st item from the iterator

# Create black (foreground) graphic context
window = @screen[:root]
@foreground = XCB.generate_id(@connection)
mask = XCB::Constants::GC_FOREGROUND | XCB::Constants::GC_GRAPHICS_EXPOSURES
values = [@screen[:black_pixel], 0]
FFI::MemoryPointer.new(:uint32, values.size) do |ptr|
  ptr.write_array_of_int(values)
  XCB.create_gc(@connection, @foreground, window, mask, ptr)
end

# Create a window
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

# Map the window on the screen and flush
XCB.map_window(@connection, @window)
XCB.flush(@connection)

loop do
  ptr = XCB.wait_for_event(@connection) 
  if ptr.null?
    XCB.disconnect(@connection)
    XCB.flush(@connection)
    exit 
  end
  event = GenericEvent.new(ptr)
  code = event[:response_type] & ~0x80
  puts "got event with code: #{code}"
  case code
  when XCB::Constants::EXPOSE
    puts "exposed"
    # draw the points
    XCB.poly_point(@connection, 
                   XCB::Constants::COORD_MODE_ORIGIN,
                   @window, @foreground, 4, points)

    # draw the polygonal line
    XCB.poly_line(@connection, 
                  XCB::Constants::COORD_MODE_PREVIOUS,
                  @window, @foreground, 4, lines)

    # draw the segments
    XCB.poly_segment(@connection, @window, @foreground,
                     2, segments)

    # draw the rectangles
    XCB.poly_rectangle(@connection, @window, @foreground,
                       2, rectangles)

    # draw the arcs
    XCB.poly_arc(@connection, @window, @foreground,
                 2, arcs)

    # flush the request
    XCB.flush(@connection)
  else
    puts event[:response_type]
    # ignore it
  end
end
