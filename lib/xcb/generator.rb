
require 'rbgccxml'
require 'ffi'

module RbGCCXML
  class Typedef < Type
    def previous_type
      XMLParsing.find_type_of(self.node, "type")
    end
  end
  class ArrayType < Type
    def item_type
      XMLParsing.find_type_of(self.node, "type")
    end
  end
  class Union < Node
    def fields(name = nil, &block)
      find_nested_nodes_of_type("Field", name, &block)
    end
  end
  class Node 
    def unions(name = nil, &block)
      find_nested_nodes_of_type("Union", name, &block)
    end
  end
end

class Generator
  attr_reader :parsed_structs, :parsed_unions, 
    :name, :mod_re, :src
  attr_accessor :logger

  def log(str,sym)
    @logger.send(sym, str) if @logger
  end

  def puts(str)
    log(str, :debug)
  end

  MACHINE_TYPES = [
    ['unsigned int', :uint],
    ['int', :int],
  ]

  BASIC_TYPES = [
   [/uint8/ , :uint8],
   [/int8/ , :int8],
   [/uint16/ , :uint16],
   [/int16/ , :int16],
   [/uint32/ , :uint32],
   [/int32/ , :int32],
   [/uint64/ , :uint64],
   [/int64/ , :int64],
   [/uchar/, :uchar],
   [/char/, :char],
   [/ushort/, :ushort],
   [/short/, :short],
   [/void/ , :void],
   [/bool(ean)?/ , :bool],
   [/size/ , :size_t],
   [/float/, :float],
   [/double/, :double],
   [/long_long/, :long_long],
   [/ulong_long/, :ulong_long],
   [/ulong/ , :ulong],
   [/long/ , :long],
  ]

  def initialize(name, re, lib=nil)
    @name = name
    @mod_re = re
    @lib = (lib || name)
    @parsed_structs = {}
    @parsed_unions = {}
    yield self if block_given?
  end

  def parse(*args)
    @src = RbGCCXML.parse *args
  end

  def functions
    src.functions.select {|f| f.name =~ mod_re}
  end

  def enumerations
    src.enumerations.select {|f| f.name =~ mod_re}
  end

  def typedefs
    src.typedefs.select {|f| f.name =~ mod_re}
  end

  def structs
    src.structs.select {|f| f.name =~ mod_re}
  end

  def unions
    src.unions.select {|f| f.name =~ mod_re}
  end


  def type_for(type)
    ret = type_for_str(type.name)
    unless ret 
      ret = case type
            when RbGCCXML::PointerType
              :pointer
              #XXX transform char* into strings?
            when RbGCCXML::Typedef
              type_for(type.previous_type)
            when RbGCCXML::Struct
              get_struct(type)
            when RbGCCXML::Union
              get_union(type)
            when RbGCCXML::ArrayType
              cnt = 1 + type['max'].gsub(/\D/,'').to_i - type['min'].to_i
              [type_for(type.item_type), cnt]
            else
              raise ArgumentError.new "unhandled: #{type.class} in #{type.name}"
            end
    end
    ret
  end

  def type_with_id(id)
    src.typedefs.select{|t| t['id'] == id}.first
  end

  def type_for_str(str)
    basic_type_for(str) || machine_type_for(str)
  end

  def basic_type_for(str)
    pair = BASIC_TYPES.find do |re, sym|
      str =~ re
    end
    pair.last if pair
  end

  def machine_type_for(str)
    pair = MACHINE_TYPES.find do |c, sym|
      str == c
    end
    pair.last if pair
  end

  def syms_args_array_for(function)
    function.arguments.map{|arg| type_for(arg.cpp_type)}
  end

  def return_sym_for(function)
    type_for function.return_type
  end

  def sym_for(function)
    function.name.to_sym
  end

  def ffi_attach_args_for(function)
    [:sym_for, :syms_args_array_for, :return_sym_for].map{|sym| send(sym, function)}
  end

  def syms_pair_for(field)
    [sym_for(field), type_for(field.cpp_type)]
  end

  def syms_pairs_array_for_struct(struct)
    struct.variables.map do |field|
      syms_pair_for(field)
    end
  end

  def syms_pairs_array_for_union(struct)
    struct.fields.map do |field|
      syms_pair_for(field)
    end
  end

  def ffi_struct_layout_for(struct)
    [:sym_for, :syms_pairs_array_for_struct].map{|sym| send(sym, struct)}
  end

  def ffi_union_layout_for(struct)
    [:sym_for, :syms_pairs_array_for_union].map{|sym| send(sym, struct)}
  end

  def build_ffi_struct_for(struct)
    klass = Class.new(FFI::Struct)
    sym, ary = ffi_struct_layout_for(struct)
    puts "S: #{sym} | #{ary.inspect}"
    klass.layout *ary.flatten
    klass
  end

  def build_ffi_union_for(union)
    klass = Class.new(FFI::Union)
    sym, ary = ffi_union_layout_for(union) #struct and union are similar
    puts "U: #{sym} | #{ary.inspect}"
    klass.layout *ary.flatten
    klass
  end

  def get_struct(struct)
    @parsed_structs[sym_for(struct)] ||= build_ffi_struct_for(struct)
  end

  def get_union(union)
    @parsed_unions[sym_for(union)] ||= build_ffi_union_for(union)
  end

  def syms_and_number_args_array_for(enum)
    enum.values.map{|v| [sym_for(v), v.value]}.flatten.compact
  end

  def ffi_enum_args_for(enum)
    [:sym_for, :syms_and_number_args_array_for].map{|sym| send(sym, enum)}
  end

  def generate_enum(mod, enum_sym)
    enum = enumerations.find{|e| enum_sym.to_sym == e.name.to_sym }
    return false unless enum
    sym, ary = ffi_enum_args_for(enum)
    puts "E: #{sym} | #{ary.inspect}"
    mod.enum *ffi_enum_args_for(enum) #no * because only one array
    true
  end

  def generate_function(mod, function_sym)
    function = functions.find{|f| function_sym.to_sym == f.name.to_sym }
    return false unless function
    sym, ary = ffi_attach_args_for(function)
    puts "F: #{sym} | #{ary.inspect}"
    mod.attach_function *ffi_attach_args_for(function)
    true
  end
end
