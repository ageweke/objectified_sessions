require 'objectified_sessions'
require 'objectified_sessions/helpers/exception_helpers'

describe ObjectifiedSessions::Base do
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    @class = Class.new(::ObjectifiedSessions::Base)
    @underlying_session = double("underlying_session")
  end

  def allow_prefix!(prefix)
    @prefixed_underlying_session = double("prefixed_underlying_session")
    allow(@underlying_session).to receive(:[]).with(prefix.to_s).and_return(@prefixed_underlying_session)
  end

  def new_instance!
    @instance = @class.new(@underlying_session)
  end

  def expect_and_create_field!(name, storage_name, allow_access_to_data, delete_data_with_storage_name, options)
    out = double("field_#{name}")

    allow(out).to receive(:name).with().and_return(name.to_sym)
    allow(out).to receive(:storage_name).with().and_return(storage_name.to_s)
    allow(out).to receive(:allow_access_to_data?).with().and_return(allow_access_to_data)
    allow(out).to receive(:delete_data_with_storage_name?).with().and_return(delete_data_with_storage_name)
    expect(ObjectifiedSessions::FieldDefinition).to receive(:new).once.with(@class, name, options).and_return(out)

    out
  end

  describe "deletion of unknown fields" do
    before :each do
      allow(@underlying_session).to receive(:keys).with().and_return([ :foo, :bar, :baz ])
    end

    def expect_deletion(expected_deleted_keys)
      expect(@underlying_session).to receive(:delete).once do |keys|
        unless keys.sort_by(&:to_s) == expected_deleted_keys.sort_by(&:to_s)
          raise "Unexpected keys passed: #{keys.inspect}; expected: #{expected_deleted_keys.inspect}"
        end
      end

      new_instance!
    end

    it "should delete unknown fields on startup if unknown_fields == :delete" do
      @class.unknown_fields :delete

      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      expect_deletion([ :bar, :baz ])
    end

    it "should also delete fields that have delete_data_with_storage_name == true" do
      @class.unknown_fields :delete

      @field_foo = expect_and_create_field!(:foo, 'foo', true, true, { :type => :normal, :visibility => :public })
      @class.field :foo

      expect_deletion([ :foo, :bar, :baz ])
    end

    it "should delete fields based on storage name, not name" do
      @class.unknown_fields :delete

      @field_foo = expect_and_create_field!(:foo, 'bar', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      expect_deletion([ :foo, :baz ])
    end

    it "should not delete fields if unknown_fields is not set" do
      @field_foo = expect_and_create_field!(:foo, 'bar', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      new_instance!
    end

    it "should not delete fields if unknown_fields is set to :preserve" do
      @class.unknown_fields :preserve

      @field_foo = expect_and_create_field!(:foo, 'bar', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      new_instance!
    end

    it "should only delete data within the prefix, if one is set" do
      @class.prefix :prf
      @class.unknown_fields :delete

      allow_prefix!(:prf)

      allow(@underlying_session).to receive(:keys).with().and_return([ :foo, :bar, :baz, :prf ])
      allow(@prefixed_underlying_session).to receive(:keys).with().and_return([ :foo, :quux, :marph ])

      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      expect(@prefixed_underlying_session).to receive(:delete).once do |keys|
        unless keys.sort_by(&:to_s) == [ :quux, :marph ].sort_by(&:to_s)
          raise "Unexpected keys passed: #{keys.inspect}"
        end
      end

      new_instance!
    end
  end

  describe "retrieving field names" do
    before :each do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo
      @field_bar = expect_and_create_field!(:bar, 'bar', true, false, { :type => :normal, :visibility => :public })
      @class.field :bar
      @field_baz = expect_and_create_field!(:baz, 'baz', true, false, { :type => :normal, :visibility => :public })
      @class.field :baz
      @field_ret = expect_and_create_field!(:ret, 'ret', false, true, { :type => :retired, :visibility => :public })
      @class.retired :ret
      @field_ina = expect_and_create_field!(:ina, 'ina', false, false, { :type => :inactive, :visibility => :public })
      @class.inactive :ina
    end

    it "should return all normal fields, but not active or retired, from the class" do
      @class.accessible_field_names.sort_by { |x| x.to_s }.should == %w{foo bar baz}.map { |x| x.to_sym }.sort_by { |x| x.to_s }
    end

    it "should return all normal fields, but not active or retired, from the instance" do
      instance = new_instance!
      instance.field_names.sort_by { |x| x.to_s }.should == %w{foo bar baz}.map { |x| x.to_sym }.sort_by { |x| x.to_s }
    end
  end

  describe "reading fields" do
    before :each do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      new_instance!
    end

    it "should raise if asked for a field that doesn't exist" do
      e = capture_exception(ObjectifiedSessions::Errors::NoSuchFieldError) { @instance.send(:[], :bar) }
      e.session_class.should be(@class)
      e.field_name.should == :bar
      e.message.should match(/bar/i)
      e.message.should match(/foo/i)
    end

    it "should return data if present" do
      allow(@underlying_session).to receive(:[]).with('foo').and_return(123)
      @instance.send(:[], 'foo').should == 123
    end

    it "should return data via the prefix, if one is set" do
      @class.prefix :prf
      allow_prefix!(:prf)

      allow(@prefixed_underlying_session).to receive(:[]).with('foo').and_return(234)
      allow(@underlying_session).to receive(:[]).with('foo').and_return(345)

      @instance.send(:[], 'foo').should == 234
    end

    it "should not bind a hash to the prefix, if none is there" do
      @class.prefix :prf

      allow(@underlying_session).to receive(:[]).with('prf').and_return(nil)

      @instance.send(:[], 'foo').should == nil
    end
  end

  describe "writing fields" do
    before :each do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      new_instance!
    end

    it "should raise if asked for a field that doesn't exist" do
      e = capture_exception(ObjectifiedSessions::Errors::NoSuchFieldError) { @instance.send(:[]=, :bar, 123) }
      e.session_class.should be(@class)
      e.field_name.should == :bar
      e.message.should match(/bar/i)
      e.message.should match(/foo/i)
    end

    it "should assign data" do
      expect(@underlying_session).to receive(:[]=).once.with('foo', 123)
      @instance.send(:[]=, :foo, 123).should == 123
    end

    it "should assign data via the prefix, if one is set" do
      @class.prefix :prf
      allow_prefix!(:prf)

      expect(@prefixed_underlying_session).to receive(:[]=).once.with('foo', 123)

      @instance.send(:[]=, 'foo', 123).should == 123
    end

    it "should bind a hash to the prefix, if none is there" do
      @class.prefix :prf


      @prefixed_underlying_session = double("prefixed_underlying_session")
      expect(@underlying_session).to receive(:[]).once.ordered.with('prf').and_return(nil)
      expect(@underlying_session).to receive(:[]=).once.ordered.with('prf', { })
      expect(@underlying_session).to receive(:[]).once.ordered.with('prf').and_return(@prefixed_underlying_session)

      expect(@prefixed_underlying_session).to receive(:[]=).once.with('foo', 123)
      @instance.send(:[]=, 'foo', 123).should == 123
    end
  end

  describe "defining fields" do
    it "should define a simple field, and make it retrievable" do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      @class._field_named(:foo).should be(@field_foo)
      @class._field_named('foo').should be(@field_foo)
      @class._field_with_storage_name(:foo).should be(@field_foo)
      @class._field_with_storage_name('foo').should be(@field_foo)
    end

    it "should allow you to change the visibility" do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :private })
      @class.field :foo, :visibility => :private

      @class._field_named(:foo).should be(@field_foo)
      @class._field_named('foo').should be(@field_foo)
      @class._field_with_storage_name(:foo).should be(@field_foo)
      @class._field_with_storage_name('foo').should be(@field_foo)
    end

    it "should respect the default visibility" do
      @class.default_visibility :private

      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :private })
      @class.field :foo

      @field_bar = expect_and_create_field!(:bar, 'bar', true, false, { :type => :normal, :visibility => :public })
      @class.field :bar, :visibility => :public

      @class.default_visibility :public

      @field_baz = expect_and_create_field!(:baz, 'baz', true, false, { :type => :normal, :visibility => :public })
      @class.field :baz
    end

    it "should allow you to change the storage name" do
      @field_foo = expect_and_create_field!(:foo, 'bar', true, false, { :type => :normal, :visibility => :public, :storage => :bar })
      @class.field :foo, :storage => :bar

      @class._field_named(:foo).should be(@field_foo)
      @class._field_named('foo').should be(@field_foo)
      @class._field_with_storage_name('foo').should == nil
      @class._field_with_storage_name(:foo).should == nil
      @class._field_with_storage_name(:bar).should be(@field_foo)
      @class._field_with_storage_name('bar').should be(@field_foo)
    end

    it "should raise if you try to define a field with the same name" do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      @field_foo = expect_and_create_field!('foo', 'bar', true, false, { :type => :normal, :visibility => :public, :storage => :bar })
      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
        @class.field 'foo', :storage => :bar
      end
      e.session_class.should be(@class)
      e.field_name.should == :foo
      e.message.should match(/foo/i)
    end

    it "should raise if you try to define a field with the same storage name" do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      @field_foo = expect_and_create_field!('bar', 'foo', true, false, { :type => :normal, :visibility => :public, :storage => :foo })
      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
        @class.field 'bar', :storage => :foo
      end
      e.session_class.should be(@class)
      e.original_field_name.should == :foo
      e.new_field_name.should == :bar
      e.storage_name.should == 'foo'
      e.message.should match(/foo/i)
      e.message.should match(/bar/i)
    end

    describe "inactive fields" do
      it "should allow defining an inactive field" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, false, { :type => :inactive, :visibility => :public })
        @class.inactive :foo

        @class._field_named(:foo).should be(@field_foo)
        @class._field_named('foo').should be(@field_foo)
        @class._field_with_storage_name(:foo).should be(@field_foo)
        @class._field_with_storage_name('foo').should be(@field_foo)
      end

      it "should conflict with a normal field" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, false, { :type => :inactive, :visibility => :public })
        @class.inactive :foo

        @field_foo = expect_and_create_field!('foo', 'bar', true, false, { :type => :normal, :visibility => :public, :storage => :bar })
        e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
          @class.field 'foo', :storage => :bar
        end
        e.session_class.should be(@class)
        e.field_name.should == :foo
        e.message.should match(/foo/i)
      end

      it "should raise if you try to define a field with the same storage name" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, false, { :type => :inactive, :visibility => :public })
        @class.inactive :foo

        @field_foo = expect_and_create_field!('bar', 'foo', true, false, { :type => :normal, :visibility => :public, :storage => :foo })
        e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
          @class.field 'bar', :storage => :foo
        end
        e.session_class.should be(@class)
        e.original_field_name.should == :foo
        e.new_field_name.should == :bar
        e.storage_name.should == 'foo'
        e.message.should match(/foo/i)
        e.message.should match(/bar/i)
      end
    end

    describe "retired fields" do
      it "should allow defining a retired field" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, true, { :type => :retired, :visibility => :public })
        @class.retired :foo

        @class._field_named(:foo).should be(@field_foo)
        @class._field_named('foo').should be(@field_foo)
        @class._field_with_storage_name(:foo).should be(@field_foo)
        @class._field_with_storage_name('foo').should be(@field_foo)
      end

      it "should conflict with a normal field" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, true, { :type => :retired, :visibility => :public })
        @class.retired :foo

        @field_foo = expect_and_create_field!('foo', 'bar', true, false, { :type => :normal, :visibility => :public, :storage => :bar })
        e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
          @class.field 'foo', :storage => :bar
        end
        e.session_class.should be(@class)
        e.field_name.should == :foo
        e.message.should match(/foo/i)
      end

      it "should raise if you try to define a field with the same storage name" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, true, { :type => :retired, :visibility => :public })
        @class.retired :foo

        @field_foo = expect_and_create_field!('bar', 'foo', true, false, { :type => :normal, :visibility => :public, :storage => :foo })
        e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
          @class.field 'bar', :storage => :foo
        end
        e.session_class.should be(@class)
        e.original_field_name.should == :foo
        e.new_field_name.should == :bar
        e.storage_name.should == 'foo'
        e.message.should match(/foo/i)
        e.message.should match(/bar/i)
      end
    end
  end

  it "should set and return the default visibility properly" do
    @class.default_visibility.should == :public
    @class.default_visibility :private
    @class.default_visibility.should == :private
    lambda { @class.default_visibility :foobar }.should raise_error(ArgumentError)
    lambda { @class.default_visibility 12345 }.should raise_error(ArgumentError)
    @class.default_visibility.should == :private
    @class.default_visibility :public
    @class.default_visibility.should == :public
  end

  it "should set and return the prefix properly" do
    @class.prefix.should == nil
    @class.prefix :prf
    @class.prefix.should == 'prf'
    @class.prefix 'BaZ'
    @class.prefix.should == 'BaZ'
    lambda { @class.prefix 12345 }.should raise_error(ArgumentError)
    lambda { @class.prefix 4.3 }.should raise_error(ArgumentError)
    @class.prefix.should == 'BaZ'
    @class.prefix nil
    @class.prefix.should == nil
  end

  it "should set and return #unknown_fields properly" do
    @class.unknown_fields.should == :preserve
    @class.unknown_fields :delete
    @class.unknown_fields.should == :delete
    lambda { @class.unknown_fields :foo }.should raise_error(ArgumentError)
    lambda { @class.unknown_fields 12345 }.should raise_error(ArgumentError)
    @class.unknown_fields.should == :delete
    @class.unknown_fields :preserve
    @class.unknown_fields.should == :preserve
  end

  it "should allow setting allowed_value_types to any valid value, but not invalid values, and return it" do
    @class.allowed_value_types.should == :anything
    @class.allowed_value_types :primitive
    @class.allowed_value_types.should == :primitive
    @class.allowed_value_types :primitive_and_compound
    @class.allowed_value_types.should == :primitive_and_compound
    @class.allowed_value_types :anything
    @class.allowed_value_types.should == :anything
  end

  describe "new-value type validation" do
    before :each do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      @instance = new_instance!

      @scalars = [ "string", :symbol, true, false, nil, Time.now ]
      @compound = [ [ 1, 2, 3 ], { 'foo' => 123 }, [ 1, [ 2, 3 ], 4 ], { 'foo' => [ 1, 2, 3 ] } ]

      my_class = Class.new
      @arbitrary = [ /something/, my_class.new, [ 1, 2, /foo/ ], { 'foo' => /foo/ } ]
    end

    it "should allow anything by default" do
      (@scalars + @compound + @arbitrary).each do |value|
        expect(@underlying_session).to receive(:[]=).once.with('foo', value)
        @instance.send(:[]=, :foo, value)
      end
    end

    it "should allow only simple scalars for :primitive" do
      @class.allowed_value_types :primitive

      (@scalars).each do |value|
        expect(@underlying_session).to receive(:[]=).once.with('foo', value)
        @instance.send(:[]=, :foo, value)
      end

      (@compound + @arbitrary).each do |value|
        lambda { @instance.send(:[]=, :foo, value) }.should raise_error(ArgumentError)
      end
    end

    it "should allow simple scalars and compounds of those for :primitive_and_compound" do
      @class.allowed_value_types :primitive_and_compound

      (@scalars + @compound).each do |value|
        expect(@underlying_session).to receive(:[]=).once.with('foo', value)
        @instance.send(:[]=, :foo, value)
      end

      (@arbitrary).each do |value|
        lambda { @instance.send(:[]=, :foo, value) }.should raise_error(ArgumentError)
      end
    end
  end

  it "should return only fields in #accessible_field_names, return fields by name or storage name appropriately, and raise NoSuchFieldError when appropriate" do
    @field_foo = expect_and_create_field!(:foo, 'stg1', true, false, { :type => :normal, :visibility => :public, :storage => :stg1 })
    @class.field :foo, :storage => :stg1

    @field_bar = expect_and_create_field!(:bar, 'stg2', false, false, { :type => :inactive, :visibility => :public, :storage => :stg2 })
    @class.inactive :bar, :storage => :stg2

    @field_baz = expect_and_create_field!(:baz, 'stg3', false, true, { :type => :retired, :visibility => :public, :storage => :stg3 })
    @class.retired :baz, :storage => :stg3

    @field_quux = expect_and_create_field!(:quux, 'stg4', true, false, { :type => :normal, :visibility => :public, :storage => :stg4 })
    @class.field :quux, :storage => :stg4

    @class.accessible_field_names.sort_by(&:to_s).should == [ :foo, :quux ].sort_by(&:to_s)

    instance = @class.new(@underlying_session)
    instance.field_names.sort_by(&:to_s).should == [ :foo, :quux ].sort_by(&:to_s)

    expect(@underlying_session).to receive(:[]).once.with('stg1').and_return(nil)
    expect(@underlying_session).to receive(:[]).once.with('stg4').and_return(123)
    instance.keys.should == [ :quux ]

    @class._field_named(:foo).should be(@field_foo)
    @class._field_named(:bar).should be(@field_bar)
    @class._field_named(:baz).should be(@field_baz)
    @class._field_named(:quux).should be(@field_quux)
    @class._field_named('foo').should be(@field_foo)
    @class._field_named('bar').should be(@field_bar)
    @class._field_named('baz').should be(@field_baz)
    @class._field_named('quux').should be(@field_quux)

    @class._field_with_storage_name(:foo).should == nil
    @class._field_with_storage_name(:bar).should == nil
    @class._field_with_storage_name(:baz).should == nil
    @class._field_with_storage_name(:quux).should == nil
    @class._field_with_storage_name('foo').should == nil
    @class._field_with_storage_name('bar').should == nil
    @class._field_with_storage_name('baz').should == nil
    @class._field_with_storage_name('quux').should == nil

    @class._field_with_storage_name(:stg1).should be(@field_foo)
    @class._field_with_storage_name(:stg2).should be(@field_bar)
    @class._field_with_storage_name(:stg3).should be(@field_baz)
    @class._field_with_storage_name(:stg4).should be(@field_quux)
    @class._field_with_storage_name('stg1').should be(@field_foo)
    @class._field_with_storage_name('stg2').should be(@field_bar)
    @class._field_with_storage_name('stg3').should be(@field_baz)
    @class._field_with_storage_name('stg4').should be(@field_quux)

    @class._ensure_has_field_named(:foo)
    @class._ensure_has_field_named(:quux)
    @class._ensure_has_field_named('foo')
    @class._ensure_has_field_named('quux')

    lambda { @class._ensure_has_field_named(:bar) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named(:baz) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named('bar') }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named('baz') }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)

    lambda { @class._ensure_has_field_named(:stg1) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named(:stg2) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named(:stg3) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named(:stg4) }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named('stg1') }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named('stg2') }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named('stg3') }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
    lambda { @class._ensure_has_field_named('stg4') }.should raise_error(ObjectifiedSessions::Errors::NoSuchFieldError)
  end

  it "should return a dynamic-methods module that's configured correctly" do
    ::Object.const_set(:ObjectifiedSessionsSpecClassDmm, @class)

    mod = @class._dynamic_methods_module
    @class.included_modules.include?(mod).should be
    mod.name.should == "ObjectifiedSessionsSpecClassDmm::ObjectifiedSessionsDynamicMethods"

    mod.define_method("foo") { "foo!" }
    instance = @class.new(@underlying_session)
    instance.foo.should == "foo!"

    mod.define_method("bar") { "bar!" }
    mod.private :bar
    instance = @class.new(@underlying_session)
    instance.respond_to?(:bar).should_not be
    instance.send(:bar).should == "bar!"

    @class._dynamic_methods_module.should be(mod)
  end
end
