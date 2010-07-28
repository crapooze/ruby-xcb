
require 'ffi'
require 'xcb/generator'

class MyLog
  def debug(str)
    puts str #if str =~ /^F/
  end
end

module XCB
  extend FFI::Library

  ffi_lib 'xcb'

  NEEDED_METHODS = [
    :xcb_generate_id,
    :xcb_get_setup,
    :xcb_setup_roots_iterator,
    :xcb_create_window,
    :xcb_map_window,
    :xcb_flush,
    :xcb_disconnect,
    :xcb_get_file_descriptor,
    :xcb_wait_for_event,
    :xcb_poll_for_event,
    :xcb_connection_has_error,
    :xcb_intern_atom,
    :xcb_intern_atom_reply,
    :xcb_create_gc,
    :xcb_poly_point,
    :xcb_poly_line,
    :xcb_poly_segment,
    :xcb_poly_arc,
    :xcb_poly_rectangle
  ]

  NEEDED_UNIONS = [
  ]

  NEEDED_ENUMS = [
    :xcb_gc_t, 
    :xcb_cw_t, 
    :xcb_event_mask_t,
    :xcb_window_class_t,
    :xcb_coord_mode_t,
  ]

  NEEDED_STRUCTS = [
    :xcb_screen_t,
    :xcb_point_t,
    :xcb_segment_t,
    :xcb_rectangle_t,
    :xcb_arc_t,
    :xcb_generic_event_t,
    :xcb_intern_atom_reply_t
  ]

  def self.struct(name)
    generator.parsed_structs[name]
  end

  def self.generator
    @generator ||= Generator.new('xcb', /^xcb_.*/) do |g|
      g.parse('/usr/include/xcb/xcb.h')
      #g.logger = MyLog.new
      g.structs.each do |struct| 
        g.get_struct(struct) if NEEDED_STRUCTS.include?(struct.name.to_sym)
      end
      g.unions.each do |union| 
        g.get_union(union) if NEEDED_UNIONS.include?(union.name.to_sym)
      end
      NEEDED_ENUMS.each do |sym|
        g.generate_enum(self, sym)
      end
      NEEDED_METHODS.each do |meth|
        g.generate_function(self, meth)
      end
    end
  end

  def self.method_missing(meth, *args, &blk)
    sym = "xcb_#{meth}"
    if respond_to?(sym)
      send(sym,*args, &blk) 
    else
      raise NoMethodError.new("could not find #{meth} or #{sym} in #{self}")
    end
  end

  module Constants
    COPY_FROM_PARENT = 0
    NONE = 0
    CURRENT_TIME = 0
    NO_SYMBOL = 0
    EXPOSE = 12

    def self.const_missing(sym)
      sym_alt = "XCB_#{sym}".to_sym
      ret = XCB.enum_value(sym) || XCB.enum_value(sym_alt)
      raise RuntimeError.new("unknown constant / enum value: #{sym} or #{sym_alt}") unless ret
      ret
    end
  end

=begin
  HAND WRITTEN CORRECTIONS
=end

  attach_function :xcb_connect, [:string, :int], :pointer

  generator
end
