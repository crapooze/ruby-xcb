
$LOAD_PATH.unshift 'lib'

require 'xcb/generator'

g = Generator.new('xcb', /^xcb_.*/)
g.parse('/usr/include/xcb/xcb.h')
e = g.src.enumerations.select{|e| e.name == 'xcb_cw_t'}.first
p g.ffi_enum_args_for(e)
    
__END__
u = g.src.unions.select{|s| s.name == 'xcb_client_message_data_t'}.first
g.get_union(u)
