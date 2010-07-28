
$LOAD_PATH.unshift 'lib'

require 'xcb'

Screen = XCB.struct(:xcb_screen_t)
@connection = XCB.connect(nil, 0)
setup = XCB.get_setup(@connection)
p_iterator = XCB.setup_roots_iterator(setup)
@screen = Screen.new(p_iterator)

puts "info on Screen: #{@screen[:root]}"
puts "\t width......: #{@screen[:width_in_pixels]}"
puts "\t height.....: #{@screen[:height_in_pixels]}"
puts "\t white pxl..: #{@screen[:white_pixel]}"
puts "\t black pxl..: #{@screen[:black_pixel]}"
